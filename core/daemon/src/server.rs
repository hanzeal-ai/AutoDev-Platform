use crate::protocol;
use crate::router;
use crate::runtime::RuntimePaths;
use crate::logger;
use std::error::Error;
use std::fs;
use std::io::{BufRead, BufReader, Write};
use std::os::unix::net::{UnixListener, UnixStream};
use std::sync::Arc;
use std::thread;
use std::time::Duration;

pub fn run(runtime_paths: Arc<RuntimePaths>) -> Result<(), Box<dyn Error>> {
    if runtime_paths.socket_path().exists() {
        fs::remove_file(runtime_paths.socket_path())?;
    }

    let listener = UnixListener::bind(runtime_paths.socket_path())?;
    logger::info(format!(
        "autodev-daemon listening on {}",
        runtime_paths.socket_path().display()
    ));

    for stream in listener.incoming() {
        match stream {
            Ok(stream) => {
                let runtime_paths = Arc::clone(&runtime_paths);
                thread::spawn(move || {
                    if let Err(err) = handle_client(stream, runtime_paths) {
                        logger::error_fields("client error", &[("error", err.to_string())]);
                    }
                });
            }
            Err(err) => {
                logger::error_fields("accept error", &[("error", err.to_string())]);
            }
        }
    }

    Ok(())
}

fn handle_client(
    stream: UnixStream,
    runtime_paths: Arc<RuntimePaths>,
) -> Result<(), Box<dyn Error>> {
    stream.set_read_timeout(Some(Duration::from_secs(60)))?;
    let mut writer = stream.try_clone()?;
    let mut reader = BufReader::new(stream);
    let mut line = String::new();

    loop {
        line.clear();
        let bytes = reader.read_line(&mut line)?;
        if bytes == 0 {
            break;
        }

        let trimmed = line.trim();
        if trimmed.is_empty() {
            continue;
        }

        let inbound: protocol::EnvelopeIn = match serde_json::from_str(trimmed) {
            Ok(value) => value,
            Err(err) => {
                logger::error_fields(
                    "invalid inbound json",
                    &[("error", format!("bad json: {err}"))],
                );
                let out = protocol::EnvelopeOut::error(
                    "invalid_json",
                    None,
                    None,
                    format!("bad json: {err}"),
                );
                write_envelope(&mut writer, &out)?;
                continue;
            }
        };

        let out = router::route_request(inbound, runtime_paths.as_ref());
        write_envelope(&mut writer, &out)?;
    }

    Ok(())
}

fn write_envelope(
    writer: &mut UnixStream,
    envelope: &protocol::EnvelopeOut,
) -> Result<(), Box<dyn Error>> {
    let body = serde_json::to_vec(envelope)?;
    writer.write_all(&body)?;
    writer.write_all(b"\n")?;
    writer.flush()?;
    Ok(())
}
