//
//  EditProfileView.swift
//  SMV
//
//  Clean form to edit user profile.
//

import SwiftUI

struct EditProfileView: View {

    @Environment(\.dismiss) private var dismiss
    @State private var displayName: String
    @State private var handle: String
    @State private var bio: String
    @State private var selectedGender: Gender

    enum Gender: String, CaseIterable {
        case male = "Male"
        case female = "Female"
        case other = "Other"
    }

    init() {
        let defaults = UserDefaults.standard
        _displayName = State(initialValue: defaults.string(forKey: "smv_displayName") ?? "")
        _handle = State(initialValue: defaults.string(forKey: "smv_handle") ?? "")
        _bio = State(initialValue: defaults.string(forKey: "smv_bio") ?? "")
        let genderRaw = defaults.string(forKey: "smv_gender") ?? "Male"
        _selectedGender = State(initialValue: Gender(rawValue: genderRaw) ?? .male)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: SMVSpacing.xxl) {
                    // Avatar
                    VStack(spacing: SMVSpacing.md) {
                        ZStack {
                            Circle()
                                .fill(Color.smvSurface2)
                                .frame(width: 80, height: 80)
                            Text(displayName.prefix(1).uppercased())
                                .font(SMVFont.displaySmall())
                                .foregroundStyle(Color.smvCyan)
                        }
                        Button("Change Photo") { }
                            .font(SMVFont.caption())
                            .foregroundStyle(Color.smvCyan)
                    }
                    .padding(.top, SMVSpacing.xxl)

                    // Fields
                    VStack(spacing: SMVSpacing.lg) {
                        fieldRow(title: "Display Name", text: $displayName, placeholder: "Your name")
                        fieldRow(title: "Handle", text: $handle, placeholder: "username")
                        bioRow(title: "Bio", text: $bio, placeholder: "Tell us about your journey")

                        // Gender picker
                        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
                            Text("Gender")
                                .font(SMVFont.micro())
                                .foregroundStyle(Color.smvTextTertiary)
                                .textCase(.uppercase)
                                .tracking(1)

                            HStack(spacing: SMVSpacing.sm) {
                                ForEach(Gender.allCases, id: \.self) { gender in
                                    Button {
                                        selectedGender = gender
                                    } label: {
                                        Text(gender.rawValue)
                                            .font(SMVFont.caption())
                                            .foregroundStyle(selectedGender == gender ? .white : Color.smvTextSecondary)
                                            .padding(.horizontal, SMVSpacing.lg)
                                            .padding(.vertical, SMVSpacing.sm)
                                            .background(
                                                RoundedRectangle(cornerRadius: SMVRadius.sm)
                                                    .fill(selectedGender == gender ? Color.smvCyan.opacity(0.2) : Color.smvSurface2)
                                            )
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, SMVSpacing.xxl)
                }
            }
            .background(Color.smvBackground)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.smvTextSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .foregroundStyle(Color.smvCyan)
                        .fontWeight(.semibold)
                }
            }
        }
    }

    @ViewBuilder
    private func fieldRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
            Text(title)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
                .textCase(.uppercase)
                .tracking(1)
            TextField(placeholder, text: text)
                .font(SMVFont.body())
                .foregroundStyle(.white)
                .padding(SMVSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SMVRadius.sm)
                        .fill(Color.smvSurface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: SMVRadius.sm)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                )
        }
    }

    @ViewBuilder
    private func bioRow(title: String, text: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
            Text(title)
                .font(SMVFont.micro())
                .foregroundStyle(Color.smvTextTertiary)
                .textCase(.uppercase)
                .tracking(1)
            TextField(placeholder, text: text, axis: .vertical)
                .font(SMVFont.body())
                .foregroundStyle(.white)
                .lineLimit(3...5)
                .padding(SMVSpacing.md)
                .background(
                    RoundedRectangle(cornerRadius: SMVRadius.sm)
                        .fill(Color.smvSurface1)
                        .overlay(
                            RoundedRectangle(cornerRadius: SMVRadius.sm)
                                .stroke(Color.white.opacity(0.04), lineWidth: 0.5)
                        )
                )
        }
    }

    private func save() {
        let defaults = UserDefaults.standard
        defaults.set(displayName, forKey: "smv_displayName")
        defaults.set(handle, forKey: "smv_handle")
        defaults.set(bio, forKey: "smv_bio")
        defaults.set(selectedGender.rawValue, forKey: "smv_gender")
        dismiss()
    }
}
