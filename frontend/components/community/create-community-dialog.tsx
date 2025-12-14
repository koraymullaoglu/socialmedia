"use client"

import type React from "react"
import { useState } from "react"
import { Loader2, Users } from "lucide-react"
import { Button } from "@/components/ui/button"
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
  DialogTrigger,
} from "@/components/ui/dialog"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { RadioGroup, RadioGroupItem } from "@/components/ui/radio-group"
import { Textarea } from "@/components/ui/textarea"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import type { Community } from "@/lib/types"

interface CreateCommunityDialogProps {
  onCommunityCreated?: (community: Community) => void
}

export function CreateCommunityDialog({ onCommunityCreated }: CreateCommunityDialogProps) {
  const { toast } = useToast()
  const [open, setOpen] = useState(false)
  const [name, setName] = useState("")
  const [description, setDescription] = useState("")
  const [privacyId, setPrivacyId] = useState("1")
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()
    if (!name.trim() || !description.trim() || isSubmitting) return

    setIsSubmitting(true)
    try {
      const community = await api.createCommunity({
        name: name.trim(),
        description: description.trim(),
        privacy_id: Number(privacyId),
      })

      toast({
        title: "Community created",
        description: `${community.name} has been created successfully!`,
      })

      setOpen(false)
      setName("")
      setDescription("")
      setPrivacyId("1")
      onCommunityCreated?.(community)
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to create community",
        variant: "destructive",
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button className="gap-2">
          <Users className="h-4 w-4" />
          Create Community
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[500px]">
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Create a New Community</DialogTitle>
            <DialogDescription>
              Start a community around shared interests. Choose a name and privacy setting.
            </DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="name">Community Name</Label>
              <Input
                id="name"
                placeholder="e.g., Tech Talk"
                value={name}
                onChange={(e) => setName(e.target.value)}
                disabled={isSubmitting}
                required
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                placeholder="What is your community about?"
                value={description}
                onChange={(e) => setDescription(e.target.value)}
                disabled={isSubmitting}
                required
                className="min-h-[100px]"
              />
            </div>
            <div className="grid gap-2">
              <Label>Privacy</Label>
              <RadioGroup value={privacyId} onValueChange={setPrivacyId} disabled={isSubmitting}>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="1" id="public" />
                  <Label htmlFor="public" className="font-normal">
                    Public - Anyone can join and see posts
                  </Label>
                </div>
                <div className="flex items-center space-x-2">
                  <RadioGroupItem value="2" id="private" />
                  <Label htmlFor="private" className="font-normal">
                    Private - Requires approval to join
                  </Label>
                </div>
              </RadioGroup>
            </div>
          </div>
          <DialogFooter>
            <Button type="button" variant="outline" onClick={() => setOpen(false)}>
              Cancel
            </Button>
            <Button type="submit" disabled={isSubmitting || !name.trim() || !description.trim()}>
              {isSubmitting ? (
                <>
                  <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                  Creating...
                </>
              ) : (
                "Create Community"
              )}
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
