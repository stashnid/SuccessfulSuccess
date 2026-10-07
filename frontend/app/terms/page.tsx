import Link from "next/link"

export const metadata = { title: "Terms of use — SuccessfulSuccess" }

export default function TermsPage() {
  return (
    <main className="mx-auto w-full max-w-3xl space-y-6 px-6 py-12">
      <Link href="/" className="underline">SuccessfulSuccess home</Link>
      <h1 className="text-3xl font-bold">Terms of use</h1>
      <p>Updated October 7, 2026. SuccessfulSuccess is an educational demonstration operated by Stanislav Hnidyk for creating and managing meetings.</p>
      <h2 className="text-xl font-semibold">Using the application</h2>
      <p>Use your own account and enter only meeting and participant information you have permission to provide. Do not attempt to access another user&apos;s records, disrupt the service or upload unlawful content. Avoid storing sensitive information in this demonstration.</p>
      <h2 className="text-xl font-semibold">Availability</h2>
      <p>The application is provided for learning and demonstration. Features and availability may change, and the service may be reset or discontinued. Keep a separate copy of information you need; do not rely on this demonstration for critical scheduling.</p>
      <h2 className="text-xl font-semibold">Privacy and contact</h2>
      <p>Read our <Link href="/privacy/" className="underline">privacy policy</Link> for details about account and meeting data. For questions or account removal requests, contact <a href="mailto:hnidyk.pn@ucu.edu.ua" className="underline">hnidyk.pn@ucu.edu.ua</a>.</p>
    </main>
  )
}
