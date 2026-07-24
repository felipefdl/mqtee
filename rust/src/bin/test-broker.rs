use std::collections::HashMap;
use std::env;
use std::net::{Ipv4Addr, SocketAddr, SocketAddrV4};

use rumqttd::{Broker, Config, ConnectionSettings, RouterConfig, ServerSettings, TlsConfig};

fn main() {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("Usage: test-broker <cert_path> <key_path>");
        std::process::exit(1);
    }
    let cert_path = &args[1];
    let key_path = &args[2];

    let router = RouterConfig {
        max_connections: 100,
        max_outgoing_packet_count: 200,
        max_segment_size: 104_857_600,
        max_segment_count: 10,
        custom_segment: None,
        initialized_filters: None,
        ..RouterConfig::default()
    };

    let connection_settings = ConnectionSettings {
        connection_timeout_ms: 60_000,
        max_payload_size: 20_480,
        max_inflight_count: 100,
        auth: None,
        external_auth: None,
        dynamic_filters: true,
    };

    let plain = ServerSettings {
        name: "plain".to_string(),
        listen: SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::LOCALHOST, 18830)),
        tls: None,
        next_connection_delay_ms: 1,
        connections: connection_settings.clone(),
    };

    let tls = ServerSettings {
        name: "tls".to_string(),
        listen: SocketAddr::V4(SocketAddrV4::new(Ipv4Addr::LOCALHOST, 18831)),
        tls: Some(TlsConfig::Rustls {
            capath: None,
            certpath: cert_path.clone(),
            keypath: key_path.clone(),
        }),
        next_connection_delay_ms: 1,
        connections: connection_settings,
    };

    let mut v4 = HashMap::new();
    v4.insert("plain".to_string(), plain);
    v4.insert("tls".to_string(), tls);

    let config = Config {
        id: 0,
        router,
        v4: Some(v4),
        ..Config::default()
    };

    let mut broker = Broker::new(config);

    println!("BROKER READY");

    broker.start().expect("Failed to start broker");
}
