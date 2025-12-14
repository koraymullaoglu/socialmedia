"use client"

import { useEffect, useRef, useState } from "react"
import Image from "next/image"
import { ChevronDown, ImageIcon, Loader2, Users, X } from "lucide-react"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Card, CardContent } from "@/components/ui/card"
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from "@/components/ui/dropdown-menu"
import { Textarea } from "@/components/ui/textarea"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { useAuth } from "@/lib/auth-context"
import type { Community, Post } from "@/lib/types"

interface CreatePostProps {
  onPostCreated?: (post: Post) => void
  defaultCommunityId?: number
  hideCommunitySelect?: boolean
}

export function CreatePost({
  onPostCreated,
  defaultCommunityId,
  hideCommunitySelect = false,
}: CreatePostProps) {
  const { user } = useAuth()
  const { toast } = useToast()
  const [content, setContent] = useState("")
  const [mediaUrl, setMediaUrl] = useState("")
  const [selectedCommunity, setSelectedCommunity] = useState<Community | null>(null)
  const [myCommunities, setMyCommunities] = useState<Community[]>([])
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [showMediaInput, setShowMediaInput] = useState(false)
  const [isLoadingCommunities, setIsLoadingCommunities] = useState(false)
  const fileInputRef = useRef<HTMLInputElement>(null)

  useEffect(() => {
    void loadMyCommunities()
  }, [])

  useEffect(() => {
    if (defaultCommunityId && myCommunities.length > 0) {
      const defaultCommunity = myCommunities.find((c) => c.id === defaultCommunityId)
      if (defaultCommunity) {
        setSelectedCommunity(defaultCommunity)
      }
    }
  }, [defaultCommunityId, myCommunities])

  const loadMyCommunities = async () => {
    setIsLoadingCommunities(true)
    try {
      const response = await api.getMyCommunities()
      setMyCommunities(response.communities || [])
    } catch (error) {
      console.error("Failed to load communities:", error)
    } finally {
      setIsLoadingCommunities(false)
    }
  }

  const handleSubmit = async () => {
    if (!content.trim() || isSubmitting) return

    setIsSubmitting(true)
    try {
      const communityId = selectedCommunity?.id || defaultCommunityId || undefined

      const post = await api.createPost({
        content: content.trim(),
        media_url: mediaUrl.trim() || undefined,
        community_id: communityId,
      })

      toast({
        title: "Success",
        description: "Your post has been published!",
      })

      setContent("")
      setMediaUrl("")
      if (!defaultCommunityId) {
        setSelectedCommunity(null)
      }
      setShowMediaInput(false)

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
          <Avatar className="h-10 w-10 flex-shrink-0">
            <AvatarImage
              src={user?.profile_picture_url || "/placeholder.svg"}
              alt={user?.username}
            />
            <AvatarFallback className="bg-gradient-to-br from-blue-500 to-cyan-500 text-white">
              {user?.username?.charAt(0).toUpperCase() || "U"}
            </AvatarFallback>
          </Avatar>

          <div className="flex-1 space-y-3">
            <Textarea
              placeholder="What's on your mind?"
              value={content}
              onChange={(e) => setContent(e.target.value)}
              className="min-h-[80px] resize-none border-none p-0 text-sm shadow-none focus-visible:ring-0"
              disabled={isSubmitting}
            />

            {showMediaInput && (
              <div className="animate-in fade-in slide-in-from-top-2 duration-200">
                <div className="flex flex-col gap-2">
                  <Button
                    type="button"
                    variant="outline"
                    className="w-full justify-start bg-transparent text-left font-normal"
                    onClick={() => fileInputRef.current?.click()}
                    disabled={isSubmitting}
                  >
                    <ImageIcon className="mr-2 h-4 w-4" />
                    {mediaUrl ? "Change Image" : "Upload Image"}
                  </Button>
                  <input
                    ref={fileInputRef}
                    type="file"
                    accept="image/*"
                    className="hidden"
                    onChange={async (e) => {
                      const file = e.target.files?.[0]
                      if (file) {
                        try {
                          const url = await api.uploadFile(file)
                          setMediaUrl(url)
                          toast({ title: "Image uploaded successfully" })
                        } catch {
                          toast({
                            title: "Upload failed",
                            description: "Failed to upload image",
                            variant: "destructive",
                          })
                        }
                      }
                      e.target.value = ""
                    }}
                    disabled={isSubmitting}
                  />
                </div>
                {mediaUrl && (
                  <div className="relative mt-2 inline-block">
                    <Image
                      src={mediaUrl || "/placeholder.svg"}
                      alt="Preview"
                      width={80}
                      height={80}
                      className="h-20 w-20 rounded-md object-cover"
                      unoptimized
                    />
                    <button
                      type="button"
                      onClick={() => setMediaUrl("")}
                      className="bg-destructive text-destructive-foreground hover:bg-destructive/90 absolute -top-2 -right-2 rounded-full p-0.5"
                    >
                      <X className="h-3 w-3" />
                    </button>
                  </div>
                )}
              </div>
            )}

            {selectedCommunity && !hideCommunitySelect && (
              <div className="bg-muted flex items-center gap-2 rounded-md px-3 py-2 text-sm">
                <Users className="h-4 w-4" />
                <span>Posting to {selectedCommunity.name}</span>
                {!defaultCommunityId && (
                  <button
                    type="button"
                    onClick={() => setSelectedCommunity(null)}
                    className="hover:text-destructive ml-auto"
                  >
                    <X className="h-3 w-3" />
                  </button>
                )}
              </div>
            )}

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
                {!hideCommunitySelect && (
                  <DropdownMenu>
                    <DropdownMenuTrigger asChild>
                      <Button
                        type="button"
                        variant={selectedCommunity ? "default" : "ghost"}
                        size="sm"
                        disabled={isSubmitting || isLoadingCommunities}
                        className="gap-2"
                      >
                        <Users className="h-4 w-4" />
                        <span className="hidden sm:inline">Community</span>
                        <ChevronDown className="h-3 w-3" />
                      </Button>
                    </DropdownMenuTrigger>
                    <DropdownMenuContent align="start" className="w-56">
                      {isLoadingCommunities ? (
                        <div className="flex items-center justify-center p-2">
                          <Loader2 className="h-4 w-4 animate-spin" />
                        </div>
                      ) : myCommunities.length === 0 ? (
                        <div className="text-muted-foreground p-2 text-sm">
                          You haven&apos;t joined any communities yet
                        </div>
                      ) : (
                        myCommunities.map((community) => (
                          <DropdownMenuItem
                            key={community.id}
                            onClick={() => setSelectedCommunity(community)}
                          >
                            <Users className="mr-2 h-4 w-4" />
                            {community.name}
                          </DropdownMenuItem>
                        ))
                      )}
                    </DropdownMenuContent>
                  </DropdownMenu>
                )}
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
