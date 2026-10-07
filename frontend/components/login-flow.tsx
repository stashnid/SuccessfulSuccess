"use client"

import Link from "next/link"
import { useRouter } from "next/navigation"
import { useEffect, useRef, useState } from "react"
import { useAuth } from "@/components/auth-provider"
import { AuthLoading } from "@/components/require-auth"
import { Button } from "@/components/ui/button"
import { isAuthConfigured } from "@/lib/auth"

export function LoginFlow({ callback = false }: { callback?: boolean }) {
  const { status, error, signIn } = useAuth()
  const router = useRouter()
  const started = useRef(false)
  const [redirectError, setRedirectError] = useState<string | null>(null)

  useEffect(() => {
    if (status === "signedIn") { router.replace("/today/"); return }
    if (callback || status !== "signedOut" || error || !isAuthConfigured || started.current) return
    started.current = true
    void signIn().catch((caught: unknown) => {
      setRedirectError(caught instanceof Error ? caught.message : "Could not open sign-in.")
    })
  }, [status, error, signIn, callback, router])

  const message = !isAuthConfigured
    ? "Sign-in is not configured yet. Please complete the Cognito setup."
    : error?.message ?? redirectError ?? (callback && status === "signedOut"
      ? "The sign-in could not be completed. Start a new sign-in from this site."
      : null)

  if (message) {
    return (
      <main className="mx-auto flex max-w-lg flex-col items-center gap-5 px-6 py-24 text-center">
        <h1 className="text-2xl font-bold">Sign-in unavailable</h1>
        <p role="alert" className="text-muted-foreground">{message}</p>
        {isAuthConfigured ? <Button asChild><a href="/login/">Try again</a></Button> : null}
        <Link className="text-sm underline" href="/">Back to home</Link>
      </main>
    )
  }
  return <AuthLoading label={callback ? "Completing sign-in…" : "Opening secure sign-in…"} />
}
