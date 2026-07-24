use criterion::{black_box, criterion_group, criterion_main, Criterion};
use mqtee_core::{MqttMessage, QosLevel, UserProperty};

fn message_construction(c: &mut Criterion) {
  let mut group = c.benchmark_group("message_construction");

  group.bench_function("new_small_payload", |b| {
    b.iter(|| {
      MqttMessage::new(
        black_box("home/floor1/room3/temperature".into()),
        black_box(vec![0u8; 64]),
        black_box(QosLevel::AtMostOnce),
        black_box(false),
      )
    })
  });

  group.bench_function("new_large_payload", |b| {
    let payload = vec![0u8; 10_000];
    b.iter(|| {
      MqttMessage::new(
        black_box("home/floor1/room3/temperature".into()),
        black_box(payload.clone()),
        black_box(QosLevel::AtLeastOnce),
        black_box(true),
      )
    })
  });

  group.bench_function("with_v5_properties_full", |b| {
    b.iter(|| {
      MqttMessage::with_v5_properties(
        black_box("home/floor1/room3/temperature".into()),
        black_box(vec![0u8; 64]),
        black_box(QosLevel::ExactlyOnce),
        black_box(true),
        black_box(Some("application/json".into())),
        black_box(Some("reply/home/floor1".into())),
        black_box(Some(vec![0xDE, 0xAD, 0xBE, 0xEF])),
        black_box(vec![
          UserProperty {
            key: "source".into(),
            value: "benchmark".into(),
          },
          UserProperty {
            key: "region".into(),
            value: "us-east-1".into(),
          },
        ]),
        black_box(Some(1)),
        black_box(Some(3600)),
      )
    })
  });

  group.bench_function("new_batch_1000", |b| {
    b.iter(|| {
      let mut messages = Vec::with_capacity(1000);
      for i in 0..1000u32 {
        messages.push(MqttMessage::new(
          format!("home/floor{}/room{}/sensor{}", i % 5, i % 10, i % 20),
          vec![0u8; 64],
          QosLevel::AtMostOnce,
          false,
        ));
      }
      black_box(messages)
    })
  });

  group.finish();
}

fn data_operations(c: &mut Criterion) {
  let mut group = c.benchmark_group("data_operations");

  // Topic string conversion at various sizes
  for size in [10, 50, 200] {
    group.bench_function(&format!("topic_string_conversion_{size}B"), |b| {
      let bytes = vec![b'a'; size];
      b.iter(|| {
        let _ = black_box(String::from_utf8_lossy(black_box(&bytes)));
      })
    });
  }

  // Payload cloning at various sizes
  for size in [64, 1_000, 10_000, 100_000] {
    group.bench_function(&format!("payload_clone_{size}B"), |b| {
      let payload = vec![0u8; size];
      b.iter(|| {
        let _ = black_box(black_box(&payload).clone());
      })
    });
  }

  group.finish();
}

criterion_group!(benches, message_construction, data_operations);
criterion_main!(benches);
