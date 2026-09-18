import SwiftUI

extension ContentView {
    @ViewBuilder
    func startButton(
        input: MainLayoutInput,
        buttonText: MainLayoutButtonText,
        style: MainLayoutStateStyle,
        live: MainLayoutLiveValues
    ) -> some View {
        let primaryAction = input.primaryAction
        let startButtonTitle = buttonText.startButtonTitle
        let repsWeightText = buttonText.repsWeightText
        let buttonBackgroundColor = style.buttonBackgroundColor
        let buttonContentColor = style.buttonContentColor
        let groupProgressText = live.groupProgressText
        let setsLeftText = live.setsLeftText

        Button {
            if let action = primaryAction, !connector.isActionPending {
                connector.sendIntent(action: action)
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                Text(startButtonTitle)
                    .font(displayFontName(size: 18))
                    .foregroundColor(buttonContentColor)
                    .watchAutoShrink(lines: 2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer().frame(height: 8)

                Text(repsWeightText)
                    .font(displayFontName(size: 24))
                    .foregroundColor(buttonContentColor)
                    .watchAutoShrink()
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !groupProgressText.isEmpty {
                    Spacer().frame(height: 6)
                    Text(groupProgressText)
                        .font(displayFontName(size: 16, weight: .medium))
                        .foregroundColor(buttonContentColor.opacity(0.9))
                        .watchAutoShrink()
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if !setsLeftText.isEmpty {
                        Text(setsLeftText)
                            .font(.custom(bodyFont, size: 12).weight(.medium))
                            .foregroundColor(buttonContentColor.opacity(0.72))
                            .watchAutoShrink()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .background(buttonBackgroundColor)
        .disabled(primaryAction == nil || connector.isActionPending)
    }

    @ViewBuilder
    func completeButton(
        input: MainLayoutInput,
        buttonText: MainLayoutButtonText,
        style: MainLayoutStateStyle,
        live: MainLayoutLiveValues
    ) -> some View {
        let currentSet = input.currentSet
        let completeTemplate = input.completeTemplate
        let buttonBackgroundColor = style.buttonBackgroundColor
        let initialReps = live.initialReps

        Button {
            if let set = currentSet, let template = completeTemplate, !connector.isActionPending {
                var action = template
                action.setID = set.id
                action.reps = Int32(selectedReps)
                action.actualWeight = template.actualWeight > 0 ? template.actualWeight : set.targetWeight
                connector.sendIntent(action: action)
            }
        } label: {
            completeButtonLabel(buttonText: buttonText, style: style, live: live)
        }
        .buttonStyle(.plain)
        .background(buttonBackgroundColor)
        .disabled(connector.isActionPending)
        .onAppear {
            selectedReps = initialReps
        }
        .onChange(of: currentSet?.id) { _ in
            selectedReps = initialReps
        }
    }

    @ViewBuilder
    private func completeButtonLabel(
        buttonText: MainLayoutButtonText,
        style: MainLayoutStateStyle,
        live: MainLayoutLiveValues
    ) -> some View {
        let completeButtonText = buttonText.completeButtonText
        let buttonContentColor = style.buttonContentColor
        let groupProgressText = live.groupProgressText
        let setsLeftText = live.setsLeftText

        VStack(alignment: .leading, spacing: 0) {
            Text(completeButtonText)
                .font(displayFontName(size: 18))
                .foregroundColor(buttonContentColor)
                .watchAutoShrink(lines: 2)
                .multilineTextAlignment(.leading)

            Spacer().frame(height: 6)

            repPickerRow(buttonText: buttonText, style: style, live: live)

            if !groupProgressText.isEmpty {
                Spacer().frame(height: 6)
                Text(groupProgressText)
                    .font(displayFontName(size: 16, weight: .medium))
                    .foregroundColor(buttonContentColor.opacity(0.9))
                    .watchAutoShrink()
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !setsLeftText.isEmpty {
                    Text(setsLeftText)
                        .font(.custom(bodyFont, size: 12).weight(.medium))
                        .foregroundColor(buttonContentColor.opacity(0.72))
                        .watchAutoShrink()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.leading, 10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func repPickerRow(
        buttonText: MainLayoutButtonText,
        style: MainLayoutStateStyle,
        live: MainLayoutLiveValues
    ) -> some View {
        let weightOnlyText = buttonText.weightOnlyText
        let buttonContentColor = style.buttonContentColor
        let repOptionMax = live.repOptionMax

        HStack(alignment: .center, spacing: 0) {
            Picker("", selection: $selectedReps) {
                ForEach(0 ... repOptionMax, id: \.self) { reps in
                    Text("\(reps)")
                        .font(displayFontName(size: 20))
                        .foregroundColor(buttonContentColor)
                        .tag(reps)
                }
            }
            .pickerStyle(.wheel)
            .labelsHidden()
            .frame(width: 44, height: 32)
            .clipped()

            Text(weightOnlyText)
                .font(displayFontName(size: 28))
                .foregroundColor(buttonContentColor)
                .watchAutoShrink()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
