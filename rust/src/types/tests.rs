use super::*;

#[test]
fn mqtt_message_new_sets_timestamp_greater_than_zero() {
  let msg = MqttMessage::new("test/topic".into(), vec![1, 2, 3], QosLevel::AtMostOnce, false);
  assert!(msg.timestamp_ms > 0);
  assert_eq!(msg.topic, "test/topic");
  assert_eq!(msg.payload, vec![1, 2, 3]);
  assert_eq!(msg.qos, QosLevel::AtMostOnce);
  assert!(!msg.retain);
  assert!(msg.content_type.is_none());
  assert!(msg.user_properties.is_empty());
}

#[test]
fn mqtt_message_with_v5_properties_sets_all_fields() {
  let msg = MqttMessage::with_v5_properties(
    "test/topic".into(),
    vec![1, 2, 3],
    QosLevel::AtLeastOnce,
    true,
    Some("application/json".into()),
    Some("reply/topic".into()),
    Some(vec![0xDE, 0xAD]),
    vec![UserProperty {
      key: "key".into(),
      value: "value".into(),
    }],
    Some(1),
    Some(3600),
  );
  assert_eq!(msg.content_type.as_deref(), Some("application/json"));
  assert_eq!(msg.response_topic.as_deref(), Some("reply/topic"));
  assert_eq!(msg.correlation_data, Some(vec![0xDE, 0xAD]));
  assert_eq!(
    msg.user_properties,
    vec![UserProperty {
      key: "key".into(),
      value: "value".into()
    }]
  );
  assert_eq!(msg.payload_format_indicator, Some(1));
  assert_eq!(msg.message_expiry_interval, Some(3600));
}

#[test]
fn qos_level_round_trips_through_rumqttc_v311() {
  let cases = [
    (QosLevel::AtMostOnce, rumqttc::QoS::AtMostOnce),
    (QosLevel::AtLeastOnce, rumqttc::QoS::AtLeastOnce),
    (QosLevel::ExactlyOnce, rumqttc::QoS::ExactlyOnce),
  ];

  for (ours, theirs) in cases {
    let converted: rumqttc::QoS = ours.into();
    assert_eq!(converted, theirs);

    let back: QosLevel = converted.into();
    assert_eq!(back, ours);
  }
}

#[test]
fn qos_level_round_trips_through_rumqttc_v5() {
  let cases = [
    (QosLevel::AtMostOnce, rumqttc::v5::mqttbytes::QoS::AtMostOnce),
    (QosLevel::AtLeastOnce, rumqttc::v5::mqttbytes::QoS::AtLeastOnce),
    (QosLevel::ExactlyOnce, rumqttc::v5::mqttbytes::QoS::ExactlyOnce),
  ];

  for (ours, theirs) in cases {
    let converted: rumqttc::v5::mqttbytes::QoS = ours.into();
    assert_eq!(converted, theirs);

    let back: QosLevel = converted.into();
    assert_eq!(back, ours);
  }
}

#[test]
fn connection_event_disconnected_carries_reason() {
  let event = ConnectionEvent::Disconnected {
    reason: "broker shutdown".into(),
    reason_code: None,
  };
  if let ConnectionEvent::Disconnected { reason, reason_code } = event {
    assert_eq!(reason, "broker shutdown");
    assert!(reason_code.is_none());
  } else {
    panic!("expected Disconnected variant");
  }
}

#[test]
fn connection_event_message_received_carries_message() {
  let msg = MqttMessage::new("t".into(), vec![], QosLevel::AtLeastOnce, true);
  let event = ConnectionEvent::MessageReceived { message: msg.clone() };
  if let ConnectionEvent::MessageReceived { message } = event {
    assert_eq!(message.topic, "t");
    assert_eq!(message.qos, QosLevel::AtLeastOnce);
    assert!(message.retain);
  } else {
    panic!("expected MessageReceived variant");
  }
}

#[test]
fn subscription_request_carries_v5_options() {
  let req = SubscriptionRequest {
    topic: "test/#".into(),
    qos: QosLevel::ExactlyOnce,
    no_local: true,
    retain_as_published: true,
    retain_handling: 2,
  };
  assert!(req.no_local);
  assert!(req.retain_as_published);
  assert_eq!(req.retain_handling, 2);
}

#[test]
fn connack_details_carries_v5_properties() {
  let event = ConnectionEvent::ConnAckDetails {
    session_present: false,
    return_code: "Success".into(),
    reason_string: Some("Welcome".into()),
    assigned_client_id: Some("server-assigned-id".into()),
    server_keep_alive: Some(60),
    maximum_qos: Some(2),
    retain_available: Some(true),
    wildcard_subscription_available: Some(true),
    subscription_identifiers_available: Some(true),
    shared_subscription_available: Some(false),
    maximum_packet_size: Some(1048576),
  };
  if let ConnectionEvent::ConnAckDetails {
    assigned_client_id,
    maximum_packet_size,
    ..
  } = event
  {
    assert_eq!(assigned_client_id.as_deref(), Some("server-assigned-id"));
    assert_eq!(maximum_packet_size, Some(1048576));
  } else {
    panic!("expected ConnAckDetails variant");
  }
}
