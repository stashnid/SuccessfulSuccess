"use client"

import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query"

import { ApiError, createMeeting, deleteMeeting, listMeetings, updateMeeting } from "@/lib/api"
import { useAuth } from "@/components/auth-provider"
import type { MeetingCreateInput } from "@/lib/types"

/** Shared cache key: the list and the header menu read the same entry. */
export const meetingsKey = (date?: string, owner?: string) => ["meetings", owner, { date: date ?? "today" }] as const

export function useMeetings(date?: string) {
  const { user, status } = useAuth()
  return useQuery({
    queryKey: meetingsKey(date, user?.sub),
    queryFn: () => listMeetings({ date }),
    enabled: status === "signedIn",
    retry: (failures, error) =>
      !(error instanceof ApiError && error.code === "api_unavailable") && failures < 3,
  })
}

export function useCreateMeeting() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (payload: MeetingCreateInput) => createMeeting(payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["meetings"] }),
  })
}

export function useUpdateMeeting() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: ({ id, payload }: { id: string; payload: MeetingCreateInput }) =>
      updateMeeting(id, payload),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["meetings"] }),
  })
}

export function useDeleteMeeting() {
  const queryClient = useQueryClient()
  return useMutation({
    mutationFn: (id: string) => deleteMeeting(id),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ["meetings"] }),
  })
}
