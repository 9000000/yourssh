use anyhow::Context;
use tokio::net::TcpStream;
use vnc::{PixelFormat, VncConnector, VncEncoding};

use crate::api::VncConfig;

/// Dials the server, performs the RFB handshake + auth, and negotiates the
/// Milestone-1 encoding set (Zrle + Raw — both surface as self-contained RGBA
/// patches). Returns a connected `VncClient`.
pub async fn vnc_connect_stage(cfg: &VncConfig) -> anyhow::Result<vnc::VncClient> {
    let addr = format!("{}:{}", cfg.target_host, cfg.target_port);
    let tcp = TcpStream::connect(&addr).await.context("TCP connect")?;

    // The password future is only polled if the server requires VNC auth; for
    // a "None"-auth server vnc-rs never calls it.
    let password = cfg.password.clone();
    let client = VncConnector::new(tcp)
        .set_auth_method(async move { Ok(password) })
        .add_encoding(VncEncoding::Zrle)
        .add_encoding(VncEncoding::Raw)
        .allow_shared(true)
        .set_pixel_format(PixelFormat::rgba())
        .build()
        .context("build VNC connector")?
        .try_start()
        .await
        .context("VNC handshake/auth")?
        .finish()
        .context("finish VNC connect")?;

    Ok(client)
}
