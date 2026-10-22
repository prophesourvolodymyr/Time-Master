use std::{net::SocketAddr, time::Duration};
use timemaster_ranked::{AppState, Config, router};

#[tokio::main(flavor = "multi_thread", worker_threads = 2)]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config = Config::from_env()?;
    if config.supabase.is_none() {
        return Err("SUPABASE_URL, SUPABASE_ANON_KEY and SUPABASE_SERVICE_ROLE_KEY are required for managed account authentication and exercise sync".into());
    }
    let bind: SocketAddr = std::env::var("RANKED_BIND")
        .unwrap_or_else(|_| {
            format!(
                "0.0.0.0:{}",
                std::env::var("PORT").unwrap_or_else(|_| "8000".into())
            )
        })
        .parse()?;
    let state = AppState::open(config).await?;
    let listener = tokio::net::TcpListener::bind(bind).await?;
    let clock = state.clone();
    let ticker = tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_millis(200));
        interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
        loop {
            interval.tick().await;
            if let Err(error) = clock.tick().await {
                eprintln!("Ranked match clock failed: {error}");
            }
        }
    });
    let cleanup = state.clone();
    let deletion_worker = tokio::spawn(async move {
        let mut interval = tokio::time::interval(Duration::from_secs(30));
        interval.set_missed_tick_behavior(tokio::time::MissedTickBehavior::Skip);
        loop {
            interval.tick().await;
            if let Err(error) = cleanup.recover_deletions().await {
                eprintln!("Pending account cleanup failed: {error}");
            }
        }
    });
    eprintln!("TimeMaster Ranked listening on {}", listener.local_addr()?);
    let result = axum::serve(
        listener,
        router(state).into_make_service_with_connect_info::<SocketAddr>(),
    )
    .with_graceful_shutdown(shutdown())
    .await;
    ticker.abort();
    deletion_worker.abort();
    result?;
    Ok(())
}

async fn shutdown() {
    #[cfg(unix)]
    {
        match tokio::signal::unix::signal(tokio::signal::unix::SignalKind::terminate()) {
            Ok(mut terminate) => {
                tokio::select! { _ = tokio::signal::ctrl_c() => {}, _ = terminate.recv() => {} }
            }
            Err(_) => {
                let _ = tokio::signal::ctrl_c().await;
            }
        }
    }
    #[cfg(not(unix))]
    {
        let _ = tokio::signal::ctrl_c().await;
    }
}
