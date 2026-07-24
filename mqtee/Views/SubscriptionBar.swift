import SwiftUI

struct SubscriptionBar: View {
    var mqttVersion: MQTTVersion
    var onSubscribe: (String, QoSLevel, Bool, Bool, RetainHandling) -> Void
    @State private var newTopic: String = ""
    @State private var newQoS: QoSLevel = .atMostOnce
    @State private var noLocal: Bool = false
    @State private var retainAsPublished: Bool = false
    @State private var retainHandling: RetainHandling = .sendOnSubscribe
    @State private var showSubscriptionConfig: Bool =
        ProcessInfo.processInfo.arguments.contains("--screenshot-subscription-config")
    @State private var subscriptionToast: String?
    @State private var toastTask: Task<Void, Never>?
    @FocusState private var isSubscribeFieldFocused: Bool
    @Namespace private var namespace
    #if !os(macOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif

    var body: some View {
        VStack(spacing: 0) {
            if let toast = subscriptionToast {
                SubscriptionToast(topic: toast)
                    .transition(
                        .asymmetric(
                            insertion: .scale(scale: 0.5, anchor: .bottom).combined(with: .opacity),
                            removal: .scale(scale: 0.8).combined(with: .opacity)
                        )
                    )
            }

            GlassEffectContainer(spacing: 4) {
                HStack(spacing: 6) {
                    Button {
                        showSubscriptionConfig.toggle()
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .buttonStyle(.plain)
                    .help("Subscription options")
                    #if os(macOS)
                    .popover(isPresented: $showSubscriptionConfig) {
                        subscriptionConfigPopover
                    }
                    #else
                    .popover(
                        isPresented: horizontalSizeClass == .regular ? $showSubscriptionConfig : .constant(false)
                    ) {
                        subscriptionConfigPopover
                    }
                    .sheet(
                        isPresented: horizontalSizeClass == .compact ? $showSubscriptionConfig : .constant(false)
                    ) {
                        subscriptionConfigPopover
                            .presentationDetents([.medium])
                            .presentationDragIndicator(.visible)
                    }
                    #endif

                    TextField("Subscribe, e.g. sensors/#", text: $newTopic)
                        .textFieldStyle(.plain)
                        .autocorrectionDisabled()
                        #if !os(macOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .focused($isSubscribeFieldFocused)
                        .onSubmit { submitSubscription() }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 8))
                    .glassEffectID("topicField", in: namespace)

                    Button {
                        submitSubscription()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.glassProminent)
                    .glassEffectID("subscribeButton", in: namespace)
                    .disabled(newTopic.isEmpty)
                    .help("Subscribe")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        #if os(macOS)
        .background {
            Button("") { isSubscribeFieldFocused = true }
                .keyboardShortcut("f", modifiers: .command)
                .hidden()
        }
        #endif
    }

    private var subscriptionConfigPopover: some View {
        Grid(alignment: .leading, verticalSpacing: 10) {
            GridRow {
                Text("QoS")
                    .foregroundStyle(.secondary)
                    .gridColumnAlignment(.leading)
                Picker("QoS", selection: $newQoS) {
                    ForEach(QoSLevel.allCases, id: \.self) { level in
                        Text("\(level.rawValue) - \(level.description)")
                            .tag(level)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .gridColumnAlignment(.trailing)
            }

            if mqttVersion == .v5 {
                Divider()
                    .gridCellColumns(2)

                GridRow {
                    Text("No Local")
                    Toggle("No Local", isOn: $noLocal)
                        .labelsHidden()
                }

                GridRow {
                    Text("Retain As Published")
                    Toggle("Retain As Published", isOn: $retainAsPublished)
                        .labelsHidden()
                }

                GridRow {
                    Text("Retain Handling")
                        .foregroundStyle(.secondary)
                    Picker("Retain Handling", selection: $retainHandling) {
                        ForEach(RetainHandling.allCases, id: \.self) { handling in
                            Text(handling.description)
                                .tag(handling)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            }
        }
        .padding()
        #if os(macOS)
        .frame(width: 300)
        #else
        .frame(maxWidth: 340)
        #endif
    }

    private func submitSubscription() {
        guard !newTopic.isEmpty else { return }
        let topic = newTopic
        onSubscribe(newTopic, newQoS, noLocal, retainAsPublished, retainHandling)
        newTopic = ""
        isSubscribeFieldFocused = false

        toastTask?.cancel()
        withAnimation(BrandTheme.springSnappy) {
            subscriptionToast = topic
        }
        toastTask = Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard !Task.isCancelled else { return }
            withAnimation(BrandTheme.springSnappy) {
                subscriptionToast = nil
            }
        }
    }
}

private struct SubscriptionToast: View {
    var topic: String
    @State private var showCheck = false

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .fontWeight(.semibold)
                .padding(4)
                .glassEffect(.regular, in: .circle)
                .symbolEffect(.bounce, value: showCheck)
                .scaleEffect(showCheck ? 1 : 0.3)

            Text(topic)
                .lineLimit(1)
                .fontWeight(.medium)
        }
        .font(.callout)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(BrandTheme.springSnappy) {
                showCheck = true
            }
        }
    }
}
