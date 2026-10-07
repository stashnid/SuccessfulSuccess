import { UserManager, WebStorageStateStore } from "oidc-client-ts"

export const authConfig = {
  userPoolId: process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID ?? "",
  clientId: process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID ?? "",
  domain: process.env.NEXT_PUBLIC_COGNITO_DOMAIN ?? "",
}
export const isAuthConfigured = Boolean(authConfig.userPoolId && authConfig.clientId && authConfig.domain)
let manager: UserManager | null = null
let renewing: Promise<string | null> | null = null
export const LOGOUT_STORAGE_KEY = "successfulsuccess.auth.logout"

/** Shared by React and the API client; only created in the browser. */
export function getUserManager(): UserManager | null {
  if (typeof window === "undefined" || !isAuthConfigured) return null
  if (!manager) {
    const region = authConfig.userPoolId.split("_")[0]
    manager = new UserManager({
      authority: `https://cognito-idp.${region}.amazonaws.com/${authConfig.userPoolId}`,
      client_id: authConfig.clientId,
      redirect_uri: `${window.location.origin}/auth/callback/`,
      response_type: "code",
      scope: "openid email profile",
      loadUserInfo: false,
      automaticSilentRenew: true,
      monitorSession: false,
      // The library generates PKCE and state. Storage survives Cognito redirects.
      stateStore: new WebStorageStateStore({ store: window.sessionStorage }),
      userStore: new WebStorageStateStore({ store: window.sessionStorage }),
    })
  }
  return manager
}

export async function getAccessToken(): Promise<string | null> {
  const current = getUserManager()
  if (!current) return null
  const user = await current.getUser()
  if (!user) return null
  if (!user.expired) return user.access_token
  if (!user.refresh_token) {
    await current.removeUser()
    return null
  }
  if (!renewing) {
    renewing = current.signinSilent()
      .then((renewed) => renewed?.access_token ?? null)
      .catch(async () => { await current.removeUser(); return null })
      .finally(() => { renewing = null })
  }
  return renewing
}

export async function clearSession(): Promise<void> {
  await getUserManager()?.removeUser()
}

export async function signOut(): Promise<void> {
  const current = getUserManager()
  if (!current) return
  current.stopSilentRenew()
  await current.removeUser()
  // Sessions are stored per tab. Notify other tabs so they cannot keep showing
  // a stale signed-in user after this tab logs out.
  window.localStorage.setItem(LOGOUT_STORAGE_KEY, String(Date.now()))
  const logout = new URL(`https://${authConfig.domain}/logout`)
  logout.searchParams.set("client_id", authConfig.clientId)
  logout.searchParams.set("logout_uri", `${window.location.origin}/`)
  window.location.replace(logout.toString())
}
