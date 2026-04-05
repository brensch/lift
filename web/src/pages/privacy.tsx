import { WobblyText } from "@/components/wobbly-text";

export function PrivacyPage() {
  return (
    <div className="max-w-3xl mx-auto px-5 py-12">
      <div className="border border-border rounded-xl bg-surface p-6 md:p-10">
        <h1 className="font-display text-[clamp(1.5rem,3vw,2.2rem)] font-extrabold tracking-tight m-0">
          <WobblyText text="PRIVACY POLICY" seed={77} />
        </h1>
        <p className="mt-2 text-sm text-muted">
          Effective date: February 20, 2026
        </p>

        <p className="mt-6 text-muted leading-relaxed">
          This policy explains what data Schlift collects, why we collect it, and
          how you can control or delete it.
        </p>

        <Section title="Data We Collect">
          <ul className="list-disc pl-5 space-y-2 text-muted text-[0.95rem] leading-relaxed">
            <li>
              Account data: username, account creation time, and authentication
              credentials (for passkey login).
            </li>
            <li>
              Workout data: workouts, exercise groups, planned sets, completed
              sets, and related timestamps.
            </li>
            <li>
              Optional device telemetry: heart-rate samples from supported
              wearable integrations.
            </li>
            <li>
              Security data: session tokens and limited metadata needed to
              protect accounts and detect abuse.
            </li>
          </ul>
        </Section>

        <Section title="How We Use Data">
          <ul className="list-disc pl-5 space-y-2 text-muted text-[0.95rem] leading-relaxed">
            <li>
              Provide core functionality (saving workouts, syncing sessions, and
              powering progress/history views).
            </li>
            <li>
              Secure accounts and authenticate users through passkeys and session
              management.
            </li>
            <li>Operate and improve reliability of the service.</li>
          </ul>
        </Section>

        <Section title="Data Sharing">
          <p className="text-muted leading-relaxed">
            We do not sell your personal data. We only share data when required
            to run the service, meet legal obligations, or protect users and the
            platform.
          </p>
        </Section>

        <Section title="Data Retention">
          <p className="text-muted leading-relaxed">
            We retain data while your account is active. You can request
            immediate deletion of your account and associated data at the{" "}
            <a
              href="/delete-account"
              className="text-text underline underline-offset-2"
            >
              account deletion page
            </a>
            .
          </p>
        </Section>

        <Section title="Your Choices">
          <ul className="list-disc pl-5 space-y-2 text-muted text-[0.95rem] leading-relaxed">
            <li>You can stop using the service at any time.</li>
            <li>
              You can delete your account and workout data permanently through
              the account deletion page.
            </li>
          </ul>
        </Section>

        <Section title="Contact">
          <p className="text-muted leading-relaxed">
            For privacy requests, contact the Schlift project maintainer.
          </p>
        </Section>
      </div>
    </div>
  );
}

function Section({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <div className="mt-8">
      <h2 className="font-display text-lg font-bold tracking-tight m-0 mb-3">
        {title}
      </h2>
      {children}
    </div>
  );
}
