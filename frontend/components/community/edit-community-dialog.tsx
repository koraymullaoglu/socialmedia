"use client"

import type React from "react"
import { useState } from "react"
import { Edit, Loader2 } from "lucide-react"
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
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { Textarea } from "@/components/ui/textarea"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import type { Community, UpdateCommunityData } from "@/lib/types"

interface EditCommunityDialogProps {
  community: Community
  onCommunityUpdated: (community: Community) => void
}

export function EditCommunityDialog({ community, onCommunityUpdated }: EditCommunityDialogProps) {
  const { toast } = useToast()
  const [open, setOpen] = useState(false)
  const [isLoading, setIsLoading] = useState(false)
  const [formData, setFormData] = useState<UpdateCommunityData>({
    name: community.name,
    description: community.description,
    privacy_id: community.privacy_id,
  })

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault()

    if (!formData.name?.trim()) {
      toast({
        title: "Error",
        description: "Community name is required",
        variant: "destructive",
      })
      return
    }

    setIsLoading(true)
    try {
      const updatedCommunity = await api.updateCommunity(community.id, formData)
      toast({
        title: "Success",
        description: "Community updated successfully",
      })
      onCommunityUpdated(updatedCommunity)
      setOpen(false)
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to update community",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Dialog open={open} onOpenChange={setOpen}>
      <DialogTrigger asChild>
        <Button variant="outline" size="sm">
          <Edit className="mr-2 h-4 w-4" />
          Edit Community
        </Button>
      </DialogTrigger>
      <DialogContent className="sm:max-w-[500px]">
        <form onSubmit={handleSubmit}>
          <DialogHeader>
            <DialogTitle>Edit Community</DialogTitle>
            <DialogDescription>Update your community information</DialogDescription>
          </DialogHeader>
          <div className="grid gap-4 py-4">
            <div className="grid gap-2">
              <Label htmlFor="name">Community Name</Label>
              <Input
                id="name"
                value={formData.name || ""}
                onChange={(e) => setFormData({ ...formData, name: e.target.value })}
                placeholder="Enter community name"
                disabled={isLoading}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="description">Description</Label>
              <Textarea
                id="description"
                value={formData.description || ""}
                onChange={(e) => setFormData({ ...formData, description: e.target.value })}
                placeholder="What is your community about?"
                rows={3}
                disabled={isLoading}
              />
            </div>
            <div className="grid gap-2">
              <Label htmlFor="privacy">Privacy</Label>
              <Select
                value={formData.privacy_id?.toString()}
                onValueChange={(value) =>
                  setFormData({ ...formData, privacy_id: Number.parseInt(value) })
                }
                disabled={isLoading}
              >
                <SelectTrigger id="privacy">
                  <SelectValue />
                </SelectTrigger>
                <SelectContent>
                  <SelectItem value="1">Public</SelectItem>
                  <SelectItem value="2">Private</SelectItem>
                </SelectContent>
              </Select>
            </div>
          </div>
          <DialogFooter>
            <Button
              type="button"
              variant="outline"
              onClick={() => setOpen(false)}
              disabled={isLoading}
            >
              Cancel
            </Button>
            <Button type="submit" disabled={isLoading}>
              {isLoading && <Loader2 className="mr-2 h-4 w-4 animate-spin" />}
              Save Changes
            </Button>
          </DialogFooter>
        </form>
      </DialogContent>
    </Dialog>
  )
}
