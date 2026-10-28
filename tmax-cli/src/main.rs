mod bridge;
mod cli;
mod mcp;
mod schema;

fn main() -> std::process::ExitCode {
    cli::run(std::env::args().skip(1).collect())
}
