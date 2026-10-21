"use client"

import { useRef, useState } from "react"
import { useQueryClient } from "@tanstack/react-query"
import { toast } from "sonner"

import { Button } from "@/components/ui/button"
import { Dialog, DialogContent, DialogDescription, DialogFooter, DialogHeader, DialogTitle } from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Textarea } from "@/components/ui/textarea"
import { parseAgenda, saveAgenda } from "@/lib/api"
import type { AgendaSuggestion, Meeting, ParsedAgenda } from "@/lib/types"

const blank = (): ParsedAgenda => ({
  title: null, starts_at: null, duration_minutes: null,
  items: [{ topic: "", owner: null, minutes: null }], action_items: [], language: "en",
})

export function AgendaDialog({ meeting, open, onOpenChange }: {
  meeting?: Meeting
  open: boolean
  onOpenChange: (open: boolean) => void
}) {
  const queryClient = useQueryClient()
  const [text, setText] = useState("")
  const [agenda, setAgenda] = useState<ParsedAgenda>(meeting?.agenda ?? blank)
  const [suggestion, setSuggestion] = useState<AgendaSuggestion | null>(
    meeting?.ai_suggestion?.model && meeting.ai_suggestion.prompt_version
      ? {
        agenda: meeting.ai_suggestion.agenda,
        model: meeting.ai_suggestion.model,
        prompt_version: meeting.ai_suggestion.prompt_version,
      }
      : null,
  )
  const [freshSuggestion, setFreshSuggestion] = useState(false)
  const [touched, setTouched] = useState<Set<string>>(new Set())
  const [busy, setBusy] = useState(false)
  const [saving, setSaving] = useState(false)
  const [error, setError] = useState("")
  const controller = useRef<AbortController | null>(null)

  const change = (path: string, edit: (previous: ParsedAgenda) => ParsedAgenda) => {
    setAgenda(edit)
    setTouched((previous) => new Set(previous).add(path))
  }
  const suggested = (path: string, value: unknown) =>
    freshSuggestion && suggestion && value !== null && value !== "" && !touched.has(path)
      ? <span className="text-xs text-violet-600">Suggested</span> : null

  const parse = async () => {
    setError("")
    if (text.length > 10_000) {
      setError("Text must be 10,000 characters or fewer.")
      return
    }
    const abort = new AbortController()
    controller.current = abort
    setBusy(true)
    try {
      const result = await parseAgenda(text, abort.signal)
      setAgenda(result.agenda)
      setSuggestion(result)
      setFreshSuggestion(true)
      setTouched(new Set())
    } catch (cause) {
      if (!abort.signal.aborted) setError(cause instanceof Error ? cause.message : "Parsing failed.")
    } finally {
      setBusy(false)
      controller.current = null
    }
  }

  const save = async () => {
    if (!meeting) return
    setError("")
    const cleaned: ParsedAgenda = {
      ...agenda,
      title: agenda.title?.trim() || null,
      items: agenda.items.filter((item) => item.topic.trim()).map((item) => ({ ...item, topic: item.topic.trim() })),
      action_items: agenda.action_items.filter((item) => item.task.trim()).map((item) => ({ ...item, task: item.task.trim() })),
    }
    if (!cleaned.items.length) {
      setError("Add at least one agenda topic before saving.")
      return
    }
    setSaving(true)
    try {
      await saveAgenda(meeting.id, cleaned, suggestion)
      await queryClient.invalidateQueries({ queryKey: ["meetings"] })
      toast.success("Agenda saved")
      onOpenChange(false)
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Could not save the agenda.")
    } finally {
      setSaving(false)
    }
  }

  return <Dialog open={open} onOpenChange={(next) => {
    if (!next) controller.current?.abort()
    onOpenChange(next)
  }}>
    <DialogContent className="max-h-[90svh] overflow-y-auto sm:max-w-2xl">
      <DialogHeader>
        <DialogTitle>Agenda for {meeting?.name}</DialogTitle>
        <DialogDescription>Paste notes for a suggestion, review every field, then save.</DialogDescription>
      </DialogHeader>
      <div className="space-y-4">
        <div className="space-y-2">
          <Label htmlFor="agenda-paste">Paste an agenda</Label>
          <Textarea id="agenda-paste" value={text} onChange={(event) => setText(event.target.value)}
            rows={5} maxLength={10001} placeholder="Paste an email, chat message, or meeting notes…" />
          <p className="text-muted-foreground text-xs">{text.length}/10,000 characters</p>
          <div className="flex gap-2">
            <Button type="button" onClick={parse} disabled={busy || !text.trim()}>Parse</Button>
            {busy && <Button type="button" variant="outline" onClick={() => controller.current?.abort()}>Cancel</Button>}
          </div>
          {busy && <p role="status" className="text-sm">Reading the text and preparing a suggestion…</p>}
        </div>
        <div className="space-y-2">
          <Label htmlFor="agenda-title">Title {suggested("title", agenda.title)}</Label>
          <Input id="agenda-title" value={agenda.title ?? ""} onChange={(event) => change("title", (a) => ({ ...a, title: event.target.value || null }))} />
        </div>
        <div className="grid gap-3 sm:grid-cols-2">
          <div className="space-y-2">
            <Label htmlFor="agenda-start">Start, ISO date and time {suggested("starts_at", agenda.starts_at)}</Label>
            <Input id="agenda-start" value={agenda.starts_at ?? ""} onChange={(event) => change("starts_at", (a) => ({ ...a, starts_at: event.target.value || null }))} placeholder="2026-10-21T10:00:00+03:00" />
          </div>
          <div className="space-y-2">
            <Label htmlFor="agenda-duration">Duration, minutes {suggested("duration_minutes", agenda.duration_minutes)}</Label>
            <Input id="agenda-duration" type="number" min={1} max={600} value={agenda.duration_minutes ?? ""} onChange={(event) => change("duration_minutes", (a) => ({ ...a, duration_minutes: event.target.value ? Number(event.target.value) : null }))} />
          </div>
        </div>
        <div className="space-y-2">
          <Label htmlFor="agenda-language">Language code {suggested("language", agenda.language)}</Label>
          <Input id="agenda-language" value={agenda.language} maxLength={3}
            onChange={(event) => change("language", (a) => ({ ...a, language: event.target.value.toLowerCase() }))}
            placeholder="en or uk" />
        </div>
        <section className="space-y-3">
          <h3 className="font-semibold">Topics</h3>
          {agenda.items.map((item, index) => <div key={index} className="grid gap-2 rounded-lg border p-3 sm:grid-cols-3">
            <div className="space-y-1 sm:col-span-3">
              <Label htmlFor={`topic-${index}`}>Topic {suggested(`items.${index}.topic`, item.topic)}</Label>
              <Input id={`topic-${index}`} value={item.topic} onChange={(event) => change(`items.${index}.topic`, (a) => ({ ...a, items: a.items.map((row, i) => i === index ? { ...row, topic: event.target.value } : row) }))} />
            </div>
            <div className="space-y-1 sm:col-span-2">
              <Label htmlFor={`owner-${index}`}>Owner {suggested(`items.${index}.owner`, item.owner)}</Label>
              <Input id={`owner-${index}`} value={item.owner ?? ""} onChange={(event) => change(`items.${index}.owner`, (a) => ({ ...a, items: a.items.map((row, i) => i === index ? { ...row, owner: event.target.value || null } : row) }))} />
            </div>
            <div className="space-y-1">
              <Label htmlFor={`minutes-${index}`}>Minutes {suggested(`items.${index}.minutes`, item.minutes)}</Label>
              <Input id={`minutes-${index}`} type="number" min={1} max={480} value={item.minutes ?? ""} onChange={(event) => change(`items.${index}.minutes`, (a) => ({ ...a, items: a.items.map((row, i) => i === index ? { ...row, minutes: event.target.value ? Number(event.target.value) : null } : row) }))} />
            </div>
            <Button type="button" size="sm" variant="ghost" onClick={() => change(`items.${index}`, (a) => ({ ...a, items: a.items.filter((_, i) => i !== index) }))}>Remove topic</Button>
          </div>)}
          <Button type="button" variant="outline" onClick={() => change("items", (a) => ({ ...a, items: [...a.items, { topic: "", owner: null, minutes: null }] }))}>Add topic</Button>
        </section>
        <section className="space-y-3">
          <h3 className="font-semibold">Action items</h3>
          {agenda.action_items.map((item, index) => <div key={index} className="grid gap-2 rounded-lg border p-3 sm:grid-cols-3">
            <div className="space-y-1 sm:col-span-3"><Label htmlFor={`task-${index}`}>Task {suggested(`action_items.${index}.task`, item.task)}</Label><Input id={`task-${index}`} value={item.task} onChange={(event) => change(`action_items.${index}.task`, (a) => ({ ...a, action_items: a.action_items.map((row, i) => i === index ? { ...row, task: event.target.value } : row) }))} /></div>
            <div className="space-y-1"><Label htmlFor={`action-owner-${index}`}>Owner {suggested(`action_items.${index}.owner`, item.owner)}</Label><Input id={`action-owner-${index}`} value={item.owner ?? ""} onChange={(event) => change(`action_items.${index}.owner`, (a) => ({ ...a, action_items: a.action_items.map((row, i) => i === index ? { ...row, owner: event.target.value || null } : row) }))} /></div>
            <div className="space-y-1"><Label htmlFor={`due-${index}`}>Due {suggested(`action_items.${index}.due`, item.due)}</Label><Input id={`due-${index}`} type="date" value={item.due ?? ""} onChange={(event) => change(`action_items.${index}.due`, (a) => ({ ...a, action_items: a.action_items.map((row, i) => i === index ? { ...row, due: event.target.value || null } : row) }))} /></div>
            <Button type="button" size="sm" variant="ghost" onClick={() => change(`action_items.${index}`, (a) => ({ ...a, action_items: a.action_items.filter((_, i) => i !== index) }))}>Remove</Button>
          </div>)}
          <Button type="button" variant="outline" onClick={() => change("action_items", (a) => ({ ...a, action_items: [...a.action_items, { task: "", owner: null, due: null }] }))}>Add action item</Button>
        </section>
        {error && <p role="alert" className="text-sm text-red-600">{error}</p>}
      </div>
      <DialogFooter><Button onClick={save} disabled={saving || busy}>{saving ? "Saving…" : "Save agenda"}</Button></DialogFooter>
    </DialogContent>
  </Dialog>
}
