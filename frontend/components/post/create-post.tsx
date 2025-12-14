"use client"

import { useState } from "react"
import { ImageIcon, Loader2, Users } from "lucide-react"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import { Textarea } from "@/components/ui/textarea"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { useAuth } from "@/lib/auth-context"
import type { Post } from "@/lib/types"

interface CreatePostProps {
  onPostCreated?: (post: Post) => void
}

export function CreatePost({ onPostCreated }: CreatePostProps) {
  const { user } = useAuth()
  const { toast } = useToast()
  const [content, setContent] = useState("")
  const [mediaUrl, setMediaUrl] = useState("")
  const [communityId, setCommunityId] = useState<number | undefined>()
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [showMediaInput, setShowMediaInput] = useState(false)
  const [showCommunityInput, setShowCommunityInput] = useState(false)

  const handleSubmit = async () => {
    if (!content.trim() || isSubmitting) return

    setIsSubmitting(true)
    try {
      const post = await api.createPost({
        content: content.trim(),
        media_url: mediaUrl.trim() || undefined,
        community_id: communityId || undefined,
      })

      toast({
        title: "Success",
        description: "Your post has been published!",
      })

      // Reset form
      setContent("")
      setMediaUrl("")
      setCommunityId(undefined)
      setShowMediaInput(false)
      setShowCommunityInput(false)

      // Notify parent component
      onPostCreated?.(post)
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to create post",
        variant: "destructive",
      })
    } finally {
      setIsSubmitting(false)
    }
  }

  const isPostDisabled = !content.trim() || isSubmitting

  return (
    <Card className="mb-6 overflow-hidden shadow-sm transition-shadow hover:shadow-md">
      <CardContent className="p-4">
        <div className="flex gap-3">
          {/* User Avatar */}
          <Avatar className="h-10 w-10 flex-shrink-0">
            <AvatarImage
              src={user?.profile_picture_url || "/placeholder.svg"}
              alt={user?.username}
            />
            <AvatarFallback className="bg-gradient-to-br from-blue-500 to-cyan-500 text-white">
              {user?.username?.charAt(0).toUpperCase() || "U"}
            </AvatarFallback>
          </Avatar>

          {/* Input Area */}
          <div className="flex-1 space-y-3">
            <Textarea
              placeholder="What's on your mind?"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              className="min-h-[80px] resize-none border-none p-0 text-sm shadow-none focus-visible:ring-0"
              disabled={isSubmitting}
            />

            {/* Media URL Input */}
            {showMediaInput && (
              <div className="animate-in fade-in slide-in-from-top-2 duration-200">
                <input
                  type="url"
                  placeholder="Enter image URL..."
                  value={mediaUrl}
                  onChange={(e) => setMediaUrl(e.target.value)}
                  className="border-border bg-background focus:border-primary focus:ring-primary w-full rounded-md border px-3 py-2 text-sm transition-colors focus:ring-1 focus:outline-none"
                  disabled={isSubmitting}
                />
              </div>
            )}

            {/* Community ID Input */}
            {showCommunityInput && (
              <div className="animate-in fade-in slide-in-from-top-2 duration-200">
                <input
                  type="number"
                  placeholder="Enter community ID..."
                  value={communityId || ""}
                  onChange={(e) =>
                    setCommunityId(e.target.value ? Number(e.target.value) : undefined)
                  }
                  className="border-border bg-background focus:border-primary focus:ring-primary w-full rounded-md border px-3 py-2 text-sm transition-colors focus:ring-1 focus:outline-none"
                  disabled={isSubmitting}
                />
              </div>
            )}

            {/* Action Buttons */}
            <div className="border-border flex items-center justify-between border-t pt-3">
              <div className="flex gap-2">
                <Button
                  type="button"
                  variant={showMediaInput ? "default" : "ghost"}
                  size="sm"
                  onClick={() => setShowMediaInput(!showMediaInput)}
                  disabled={isSubmitting}
                  className="gap-2"
                >
                  <ImageIcon className="h-4 w-4" />
                  <span className="hidden sm:inline">Image</span>
                </Button>
                <Button
                  type="button"
                  variant={showCommunityInput ? "default" : "ghost"}
                  size="sm"
                  onClick={() => setShowCommunityInput(!showCommunityInput)}
                  disabled={isSubmitting}
                  className="gap-2"
                >
                  <Users className="h-4 w-4" />
                  <span className="hidden sm:inline">Community</span>
                </Button>
              </div>

              <Button
                onClick={handleSubmit}
                disabled={isPostDisabled}
                className="bg-primary hover:bg-primary/90 min-w-[80px] transition-all"
                size="sm"
              >
                {isSubmitting ? (
                  <>
                    <Loader2 className="mr-2 h-4 w-4 animate-spin" />
                    Posting...
                  </>
                ) : (
                  "Post"
                )}
              </Button>
            </div>
          </div>
        </div>
      </CardContent>
    </Card>
  )
}
