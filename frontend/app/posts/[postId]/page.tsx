"use client"

import { useEffect, useState } from "react"
import { useParams, useRouter } from "next/navigation"
import { ArrowLeft, Loader2 } from "lucide-react"
import { CommentSection } from "@/components/post/comment-section"
import { PostCard } from "@/components/post/post-card"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { ProtectedRoute } from "@/lib/protected-route"
import type { Post } from "@/lib/types"

function PostDetailPageContent() {
  const params = useParams()
  const router = useRouter()
  const { toast } = useToast()
  const [post, setPost] = useState<Post | null>(null)
  const [isLoading, setIsLoading] = useState(true)

  const postId = Number(params.postId)

  useEffect(() => {
    if (!postId) return

    const loadPost = async () => {
      setIsLoading(true)
      try {
        const feedResponse = await api.getFeed(100, 0)
        const foundPost = feedResponse.posts.find((p) => p.post_id === postId)

        if (foundPost) {
          setPost(foundPost)
        } else {
          toast({
            title: "Post not found",
            variant: "destructive",
          })
          router.push("/home")
        }
      } catch {
        toast({
          title: "Error",
          description: "Failed to load post",
          variant: "destructive",
        })
        router.push("/home")
      } finally {
        setIsLoading(false)
      }
    }

    void loadPost()
  }, [postId, router, toast])

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (!post) {
    return null
  }

  return (
    <div className="bg-background min-h-screen">
      <div className="mx-auto max-w-3xl px-4 py-8 sm:px-6 lg:px-8">
        <Button variant="ghost" className="mb-4 gap-2" onClick={() => router.back()}>
          <ArrowLeft className="h-4 w-4" />
          Back
        </Button>

        <PostCard
          post={post}
          onLikeUpdate={(_, liked, newCount) =>
            setPost({ ...post, liked_by_user: liked, like_count: newCount })
          }
        />

        <Card className="mt-6">
          <CardHeader>
            <CardTitle>Comments</CardTitle>
          </CardHeader>
          <CardContent>
            <CommentSection postId={postId} />
          </CardContent>
        </Card>
      </div>
    </div>
  )
}

export default function PostDetailPage() {
  return (
    <ProtectedRoute>
      <PostDetailPageContent />
    </ProtectedRoute>
  )
}
