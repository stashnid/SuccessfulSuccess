"use client"

import { useQueryClient } from "@tanstack/react-query"
import type { UserManager } from "oidc-client-ts"
import { AuthProvider as OidcProvider, useAuth as useOidcAuth } from "react-oidc-context"
import { createContext, useContext, useEffect, useMemo, useRef, useState } from "react"

import { syncMe } from "@/lib/api"
import { getUserManager, signOut } from "@/lib/auth"

export type AuthUser = { sub: string; email?: string; name?: string }
type AuthContextValue = {
  status: "loading" | "signedOut" | "signedIn"
  user: AuthUser | null
  error?: Error
  signIn: () => Promise<void>
  signOut: () => Promise<void>
}
const AuthContext = createContext<AuthContextValue | null>(null)
const unconfigured: AuthContextValue = {
  status: "signedOut",
  user: null,
  signIn: async () => { throw new Error("Sign-in is not configured yet.") },
  signOut: async () => {},
}

function SessionProvider({ children }: { children: React.ReactNode }) {
  const auth = useOidcAuth()
  const queryClient = useQueryClient()
  const syncedSub = useRef<string | null>(null)
  const sub = auth.isAuthenticated ? auth.user?.profile.sub : undefined
  const idToken = auth.user?.id_token
  const { events, removeUser } = auth

  useEffect(() => {
    if (syncedSub.current === (sub ?? null)) return
    queryClient.clear()
    syncedSub.current = sub ?? null
    if (sub && idToken) {
      void syncMe(idToken).catch((error) => console.warn("Profile sync failed", error))
    }
  }, [sub, idToken, queryClient])

  useEffect(() => {
    const removeExpired = events.addAccessTokenExpired(() => { void removeUser() })
    const removeFailed = events.addSilentRenewError(() => { void removeUser() })
    return () => { removeExpired(); removeFailed() }
  }, [events, removeUser])

  const value = useMemo<AuthContextValue>(() => ({
    status: auth.isLoading ? "loading" : sub ? "signedIn" : "signedOut",
    user: sub ? { sub, email: auth.user?.profile.email, name: auth.user?.profile.name } : null,
    error: auth.error,
    signIn: () => auth.signinRedirect(),
    signOut: async () => { queryClient.clear(); await signOut() },
  }), [auth, sub, queryClient])
  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const [client, setClient] = useState<{ manager: UserManager | null } | null>(null)
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect -- browser storage is unavailable during static rendering
    setClient({ manager: getUserManager() })
  }, [])

  if (!client?.manager) {
    const value = client ? unconfigured : { ...unconfigured, status: "loading" as const }
    return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
  }
  return (
    <OidcProvider
      userManager={client.manager}
      onSigninCallback={() => {
        window.history.replaceState({}, document.title, "/auth/callback/")
      }}
    >
      <SessionProvider>{children}</SessionProvider>
    </OidcProvider>
  )
}

export function useAuth() {
  const context = useContext(AuthContext)
  if (!context) throw new Error("useAuth must be used inside <AuthProvider>")
  return context
}
