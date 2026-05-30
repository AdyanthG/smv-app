//
//  LegalView.swift
//  SMV
//
//  In-app privacy policy and terms of service (required for App Store).
//

import SwiftUI

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SMVSpacing.xl) {
                Text("Last updated: May 27, 2025")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)

                section("1. Information We Collect", content: """
                • **Face Scan Data**: When you use the scan feature, we analyze your face using on-device Vision framework. Face geometry data is processed locally and never leaves your device in raw form.
                • **Scan Scores**: Your computed attractiveness scores and attribute breakdowns are stored in our cloud database (Firebase Firestore) linked to your anonymous user ID.
                • **Scan Images**: If you opt in, scan images are uploaded to secure cloud storage (Firebase Storage) for your scan history. Images are encrypted in transit and at rest.
                • **Account Information**: Display name, handle, and authentication tokens via Apple Sign-In or anonymous auth.
                • **Usage Data**: App interactions, crash reports, and analytics to improve the experience.
                """)

                section("2. How We Use Your Information", content: """
                • To calculate and display your attractiveness scores
                • To populate leaderboards and social feeds
                • To enable community features (posts, comments)
                • To improve scoring accuracy and app performance
                • To process referral rewards and premium subscriptions
                """)

                section("3. Data Storage & Security", content: """
                • All data is stored on Google Firebase infrastructure (US servers)
                • Face analysis is performed **entirely on-device** — we never send raw facial landmark data to external servers
                • All network traffic uses TLS 1.3 encryption
                • Firebase Security Rules restrict data access to authenticated users
                """)

                section("4. Data Sharing", content: """
                We do **not** sell your personal data. We may share data with:
                • **Firebase/Google**: For cloud storage and authentication
                • **Apple**: For in-app purchase processing
                • **Law enforcement**: If required by law
                """)

                section("5. Your Rights", content: """
                • **Delete Account**: Settings → Account Actions → Delete Account permanently removes all your data
                • **Export Data**: Contact us to request a data export
                • **Opt Out**: You can use the app without creating posts or uploading images
                """)

                section("6. Age Requirement", content: """
                SMV is intended for users aged 17 and older. We do not knowingly collect data from users under 17.
                """)

                section("7. Contact", content: """
                For privacy inquiries: privacy@smv.app
                """)
            }
            .padding(SMVSpacing.xxl)
            .padding(.bottom, 100)
        }
        .background(Color.smvBackground)
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func section(_ title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
            Text(title)
                .font(SMVFont.title())
                .foregroundStyle(.white)
            Text(.init(content))
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .lineSpacing(4)
        }
    }
}

struct CommunityGuidelinesView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SMVSpacing.xl) {
                Text("These guidelines keep SMV safe and respectful. Violating them may result in content removal or account suspension.")
                    .font(SMVFont.body())
                    .foregroundStyle(Color.smvTextSecondary)
                    .lineSpacing(4)

                section("Be Respectful", content: """
                • No harassment, bullying, or hate speech
                • No discrimination based on race, gender, religion, or appearance
                • Critique should be constructive, never cruel
                """)

                section("Protect Privacy", content: """
                • Only upload photos of yourself
                • Never post images of other people without their explicit consent
                • Do not share anyone's personal information
                """)

                section("Keep It Authentic", content: """
                • Do not impersonate others
                • Do not manipulate or attempt to game scores or votes
                • No spam, scams, or misleading content
                """)

                section("No Harmful Content", content: """
                • No sexually explicit, violent, or graphic material
                • No content promoting self-harm or eating disorders
                • No illegal content of any kind
                """)

                section("Reporting", content: """
                Tap the menu (•••) on any post to report it. We review every report and remove violating content. To report urgent safety concerns, contact support@smvapp.com.
                """)

                section("Enforcement", content: """
                We may remove content, restrict features, or suspend accounts that violate these guidelines. Repeat or severe violations result in permanent bans.
                """)
            }
            .padding(SMVSpacing.xxl)
            .padding(.bottom, 100)
        }
        .background(Color.smvBackground)
        .navigationTitle("Community Guidelines")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func section(_ title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
            Text(title)
                .font(SMVFont.title())
                .foregroundStyle(.white)
            Text(.init(content))
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .lineSpacing(4)
        }
    }
}

struct TermsOfServiceView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: SMVSpacing.xl) {
                Text("Last updated: May 27, 2025")
                    .font(SMVFont.micro())
                    .foregroundStyle(Color.smvTextTertiary)

                section("1. Acceptance", content: """
                By using SMV, you agree to these Terms of Service. If you do not agree, do not use the app.
                """)

                section("2. Description of Service", content: """
                SMV is a face analysis application that uses computer vision to provide attractiveness ratings on a 1-10 scale based on facial proportions and symmetry. Scores are generated algorithmically and are for entertainment and self-improvement purposes.
                """)

                section("3. User Conduct", content: """
                You agree not to:
                • Post offensive, harassing, or discriminatory content
                • Use the app to bully or harass other users
                • Upload images of other people without their consent
                • Attempt to manipulate or game the scoring system
                • Use automated tools to scrape data from the app
                """)

                section("4. Content Ownership", content: """
                • You retain ownership of photos you upload
                • By posting to the feed, you grant SMV a non-exclusive license to display your content within the app
                • You can delete your content at any time
                """)

                section("5. Subscriptions", content: """
                • SMV Pro and Elite are auto-renewable subscriptions
                • Payment is charged to your Apple ID account
                • Subscriptions auto-renew unless cancelled 24 hours before the end of the current period
                • You can manage subscriptions in Settings → Apple ID → Subscriptions
                """)

                section("6. Disclaimer", content: """
                SMV scores are algorithmically generated estimates based on facial geometry. They do not constitute medical, psychological, or professional advice. Individual attractiveness is subjective and cannot be fully captured by any algorithm.
                """)

                section("7. Limitation of Liability", content: """
                SMV is provided "as is" without warranties. We are not liable for any damages arising from your use of the app or reliance on its ratings.
                """)

                section("8. Contact", content: """
                For legal inquiries: legal@smv.app
                """)
            }
            .padding(SMVSpacing.xxl)
            .padding(.bottom, 100)
        }
        .background(Color.smvBackground)
        .navigationTitle("Terms of Service")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    private func section(_ title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: SMVSpacing.sm) {
            Text(title)
                .font(SMVFont.title())
                .foregroundStyle(.white)
            Text(.init(content))
                .font(SMVFont.body())
                .foregroundStyle(Color.smvTextSecondary)
                .lineSpacing(4)
        }
    }
}
