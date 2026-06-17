use crate::logger;
use crate::protocol;
use crate::router;
use crate::runtime::RuntimePaths;
use std::error::Error;
use std::io::{BufRead, BufReader, Read, Write};
use std::net::{TcpListener, TcpStream};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

const DEFAULT_BIND_ADDR: &str = "127.0.0.1:7373";
const RPC_PATH: &str = "/rpc";
const HEALTH_PATH: &str = "/health";

pub fn run(runtime_paths: Arc<RuntimePaths>) -> Result<(), Box<dyn Error>> {
    let bind_addr = std::env::var("AUTODEV_BIND_ADDR")
        .ok()
        .filter(|addr| !addr.trim().is_empty())
        .unwrap_or_else(default_http_bind_addr);
    let listener = TcpListener::bind(&bind_addr)?;
    logger::info(format!("autodev-daemon HTTP listening on {bind_addr}"));

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let runtime_paths = Arc::clone(&runtime_paths);
                thread::spawn(move || {
                    if let Err(err) = handle_client(stream, runtime_paths) {
                        logger::error_fields("http client error", &[("error", err.to_string())]);
                    }
                });
            }
            Err(err) => {
                logger::error_fields("http accept error", &[("error", err.to_string())]);
            }
        }
    }

    Ok(())
}

fn handle_client(
    mut stream: TcpStream,
    runtime_paths: Arc<RuntimePaths>,
) -> Result<(), Box<dyn Error>> {
    stream.set_read_timeout(Some(Duration::from_secs(60)))?;
    stream.set_write_timeout(Some(Duration::from_secs(60)))?;
    let request = read_http_request(&mut stream)?;

    if request.method == "GET" && request.path == HEALTH_PATH {
        let body = br#"{"status":"ok","transport":"http"}"#;
        write_raw_response(&mut stream, 200, "application/json", body)?;
        return Ok(());
    }

    if request.method != "POST" || request.path != RPC_PATH {
        let out = protocol::EnvelopeOut::error(
            "not_found",
            None,
            None,
            format!("unsupported route: {} {}", request.method, request.path),
        );
        stream.write_all(&build_json_response(404, &out)?)?;
        stream.flush()?;
        return Ok(());
    }

    let inbound: protocol::EnvelopeIn = match serde_json::from_slice(&request.body) {
        Ok(value) => value,
        Err(err) => {
            logger::error_fields(
                "invalid inbound http json",
                &[("error", format!("bad json: {err}"))],
            );
            let out = protocol::EnvelopeOut::error(
                "invalid_json",
                None,
                None,
                format!("bad json: {err}"),
            );
            stream.write_all(&build_json_response(400, &out)?)?;
            stream.flush()?;
            return Ok(());
        }
    };

    if router::is_streaming_command(&inbound) {
        write_stream_headers(&mut stream)?;
        router::route_streaming_request(inbound, runtime_paths.as_ref(), &mut stream);
    } else {
        let out = router::route_request(inbound, runtime_paths.as_ref());
        stream.write_all(&build_json_response(200, &out)?)?;
    }
    stream.flush()?;
    Ok(())
}

#[derive(Debug)]
struct HttpRequest {
    method: String,
    path: String,
    body: Vec<u8>,
}

fn read_http_request(stream: &mut TcpStream) -> Result<HttpRequest, Box<dyn Error>> {
    let mut reader = BufReader::new(stream.try_clone()?);
    let mut request_line = String::new();
    reader.read_line(&mut request_line)?;
    let mut parts = request_line.split_whitespace();
    let method = parts.next().unwrap_or("").to_string();
    let path = parts.next().unwrap_or("").to_string();

    let mut content_length = 0usize;
    loop {
        let mut header = String::new();
        let bytes = reader.read_line(&mut header)?;
        if bytes == 0 || header == "\r\n" || header == "\n" {
            break;
        }
        if let Some((name, value)) = header.split_once(':') {
            if name.eq_ignore_ascii_case("content-length") {
                content_length = value.trim().parse::<usize>()?;
            }
        }
    }

    let mut body = vec![0u8; content_length];
    if content_length > 0 {
        reader.read_exact(&mut body)?;
    }

    Ok(HttpRequest { method, path, body })
}

fn default_http_bind_addr() -> String {
    DEFAULT_BIND_ADDR.to_string()
}

fn build_json_response(
    status_code: u16,
    envelope: &protocol::EnvelopeOut,
) -> Result<Vec<u8>, Box<dyn Error>> {
    let body = serde_json::to_vec(envelope)?;
    let mut response = Vec::new();
    write_http_headers(
        &mut response,
        status_code,
        "application/json",
        Some(body.len()),
    )?;
    response.extend_from_slice(&body);
    Ok(response)
}

fn write_raw_response(
    writer: &mut dyn Write,
    status_code: u16,
    content_type: &str,
    body: &[u8],
) -> Result<(), Box<dyn Error>> {
    write_http_headers(writer, status_code, content_type, Some(body.len()))?;
    writer.write_all(body)?;
    writer.flush()?;
    Ok(())
}

fn write_stream_headers(writer: &mut dyn Write) -> Result<(), Box<dyn Error>> {
    write!(
        writer,
        "HTTP/1.1 200 OK\r\n\
         Content-Type: application/x-ndjson\r\n\
         Cache-Control: no-cache\r\n\
         Connection: close\r\n\
         \r\n"
    )?;
    writer.flush()?;
    Ok(())
}

fn write_http_headers(
    writer: &mut dyn Write,
    status_code: u16,
    content_type: &str,
    content_length: Option<usize>,
) -> Result<(), Box<dyn Error>> {
    let status_text = match status_code {
        200 => "OK",
        400 => "Bad Request",
        404 => "Not Found",
        500 => "Internal Server Error",
        _ => "OK",
    };
    write!(
        writer,
        "HTTP/1.1 {} {}\r\nContent-Type: {}\r\n",
        status_code, status_text, content_type
    )?;
    if let Some(length) = content_length {
        write!(writer, "Content-Length: {}\r\n", length)?;
    }
    write!(writer, "Connection: close\r\n\r\n")?;
    Ok(())
}

pub(crate) fn write_envelope(
    writer: &mut dyn Write,
    envelope: &protocol::EnvelopeOut,
) -> Result<(), Box<dyn Error>> {
    write_envelope_line(writer, envelope)
}

fn write_envelope_line(
    writer: &mut dyn Write,
    envelope: &protocol::EnvelopeOut,
) -> Result<(), Box<dyn Error>> {
    let body = serde_json::to_vec(envelope)?;
    writer.write_all(&body)?;
    writer.write_all(b"\n")?;
    writer.flush()?;
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn default_http_bind_addr_is_server_transport() {
        assert_eq!(default_http_bind_addr(), "127.0.0.1:7373");
    }

    #[test]
    fn json_response_includes_http_headers_and_envelope_body() {
        let envelope = protocol::EnvelopeOut::success(
            "corr-1".to_string(),
            1,
            protocol::MESSAGE_QUERY_GET_HEALTH_OK,
            json!({"status": "ok"}),
        );

        let response = build_json_response(200, &envelope).unwrap();
        let response_text = String::from_utf8(response).unwrap();

        assert!(response_text.starts_with("HTTP/1.1 200 OK\r\n"));
        assert!(response_text.contains("Content-Type: application/json\r\n"));
        assert!(response_text.contains("\"message_type\":\"query.get_health.ok\""));
        assert!(response_text.contains("\"status\":\"ok\""));
    }

    #[test]
    fn json_line_response_serializes_one_envelope_per_line() {
        let envelope = protocol::EnvelopeOut::success(
            "corr-1".to_string(),
            1,
            protocol::MESSAGE_COMMAND_ADD_CREATION_MESSAGE_OK,
            json!({"accepted": true}),
        );
        let mut out = Vec::new();

        write_envelope_line(&mut out, &envelope).unwrap();

        let line = String::from_utf8(out).unwrap();
        assert!(line.ends_with('\n'));
        assert!(line.contains("\"message_type\":\"command.add_creation_message.ok\""));
        assert!(line.contains("\"accepted\":true"));
    }
}
