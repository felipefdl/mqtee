use super::*;

impl From<QosLevel> for rumqttc::QoS {
  fn from(qos: QosLevel) -> Self {
    match qos {
      QosLevel::AtMostOnce => rumqttc::QoS::AtMostOnce,
      QosLevel::AtLeastOnce => rumqttc::QoS::AtLeastOnce,
      QosLevel::ExactlyOnce => rumqttc::QoS::ExactlyOnce,
    }
  }
}

impl From<rumqttc::QoS> for QosLevel {
  fn from(qos: rumqttc::QoS) -> Self {
    match qos {
      rumqttc::QoS::AtMostOnce => QosLevel::AtMostOnce,
      rumqttc::QoS::AtLeastOnce => QosLevel::AtLeastOnce,
      rumqttc::QoS::ExactlyOnce => QosLevel::ExactlyOnce,
    }
  }
}

impl From<QosLevel> for rumqttc::v5::mqttbytes::QoS {
  fn from(qos: QosLevel) -> Self {
    match qos {
      QosLevel::AtMostOnce => rumqttc::v5::mqttbytes::QoS::AtMostOnce,
      QosLevel::AtLeastOnce => rumqttc::v5::mqttbytes::QoS::AtLeastOnce,
      QosLevel::ExactlyOnce => rumqttc::v5::mqttbytes::QoS::ExactlyOnce,
    }
  }
}

impl From<rumqttc::v5::mqttbytes::QoS> for QosLevel {
  fn from(qos: rumqttc::v5::mqttbytes::QoS) -> Self {
    match qos {
      rumqttc::v5::mqttbytes::QoS::AtMostOnce => QosLevel::AtMostOnce,
      rumqttc::v5::mqttbytes::QoS::AtLeastOnce => QosLevel::AtLeastOnce,
      rumqttc::v5::mqttbytes::QoS::ExactlyOnce => QosLevel::ExactlyOnce,
    }
  }
}
