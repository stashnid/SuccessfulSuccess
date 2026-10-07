import Link from "next/link"

export const metadata = { title: "Privacy policy — SuccessfulSuccess" }

export default function PrivacyPage() {
  return (
    <main className="mx-auto w-full max-w-3xl space-y-6 px-6 py-12">
      <Link href="/" className="underline">SuccessfulSuccess home</Link>
      <h1 className="text-3xl font-bold">Privacy policy</h1>
      <p>Updated October 7, 2026. SuccessfulSuccess is an educational meeting-planning application operated by Stanislav Hnidyk.</p>
      <h2 className="text-xl font-semibold">Information we use</h2>
      <p>When you sign in with Google, we request only your basic profile and email through the openid, email and profile permissions. Your account identifier, email, email verification status, profile name and picture may be stored with your application account. We use these details to identify you, display your profile and give you access to your own meetings. We do not request access to Gmail, Google Calendar or Google Drive.</p>
      <p>We also store the meeting details and participant information you enter. Only enter information you have permission to use.</p>
      <h2 className="text-xl font-semibold">Storage and service providers</h2>
      <p>Amazon Cognito handles authentication. Application records are stored in the application database, and sign-in tokens are stored in your browser session storage. Google and Amazon Web Services process information needed to provide sign-in and hosting. The application does not receive your Google password. Passwords for email sign-in are handled by Cognito.</p>
      <p>We do not sell Google user data, use it for advertising or share it with other application users. Service providers process it to operate this application. Hosting services may also record technical information needed for operation and troubleshooting.</p>
      <h2 className="text-xl font-semibold">Your choices</h2>
      <p>You can delete your meetings in the application, sign out and revoke Google access in your Google account. Revoking access does not automatically delete existing application records. Account and profile records remain until removed by the operator; contact us to request access, correction or deletion.</p>
      <p>For privacy questions or deletion requests, email <a href="mailto:hnidyk.pn@ucu.edu.ua" className="underline">hnidyk.pn@ucu.edu.ua</a>. This policy will be updated if the application&apos;s data practices change.</p>
      <Link href="/terms/" className="inline-block underline">Terms of use</Link>
    </main>
  )
}
