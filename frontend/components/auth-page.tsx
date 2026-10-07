"use client"

import Link from "next/link"
import { useAuth } from "@/components/auth-provider"
import { SiteHeader } from "@/components/site-header"
import { UserMenu } from "@/components/user-menu"
import { Button } from "@/components/ui/button"
import { isAuthConfigured } from "@/lib/auth"

export function AuthPage() {
  const { status } = useAuth()
  return (
    <>
      <SiteHeader>
        <div className="ml-auto">
          {status === "signedIn" ? <UserMenu /> : (
            <Button asChild><Link href="/login/">Sign in</Link></Button>
          )}
        </div>
      </SiteHeader>
      <main className="mx-auto flex w-full max-w-3xl flex-1 flex-col items-center justify-center gap-6 px-6 py-20 text-center">
        <h1 className="text-gradient-canva text-4xl font-bold sm:text-5xl">Make time for your team</h1>
        <p className="text-muted-foreground max-w-lg text-lg">
          Keep your meetings, time slots and participants together. Sign in with your email or Google account.
        </p>
        <Button asChild size="lg">
          <Link href={status === "signedIn" ? "/today/" : "/login/"}>
            {status === "signedIn" ? "View your meetings" : "Sign in or create an account"}
          </Link>
        </Button>
        {!isAuthConfigured ? <p className="text-muted-foreground text-sm">Sign-in will be available after the account setup is complete.</p> : null}
      </main>
      <footer className="flex justify-center gap-6 px-6 pb-8 text-sm text-muted-foreground">
        <Link href="/privacy/" className="underline">Privacy policy</Link>
        <Link href="/terms/" className="underline">Terms of use</Link>
      </footer>
    </>
  )
}
