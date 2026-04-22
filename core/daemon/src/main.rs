mod logger;
mod protocol;
mod router;
mod runtime;
mod server;
mod store;

use std::error::Error;
use std::sync::Arc;
use std::process;

fn main() {
    if let Err(err) = run() {
        logger::error_fields("startup failed", &[("error", err.to_string())]);
        process::exit(1);
    }
}

fn run() -> Result<(), Box<dyn Error>> {
    let runtime_paths = Arc::new(runtime::RuntimePaths::discover()?);
    runtime_paths.ensure_runtime_dirs()?;
    initialize_store(runtime_paths.as_ref())?;
    server::run(runtime_paths)
}

fn initialize_store(paths: &runtime::RuntimePaths) -> Result<(), Box<dyn Error>> {
    let store = store::Store::open(paths).map_err(boxed_error)?;
    store.init_schema().map_err(boxed_error)?;
    store.seed_if_empty().map_err(boxed_error)?;
    Ok(())
}

fn boxed_error(err: String) -> Box<dyn Error> {
    err.into()
}
