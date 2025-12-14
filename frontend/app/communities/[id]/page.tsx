"use client"

import { useCallback, useEffect, useState } from "react"
import Link from "next/link"
import { useParams, useRouter } from "next/navigation"
import { ArrowLeft, Check, Loader2, Lock, Settings, Trash2, Unlock, Users } from "lucide-react"
import { EditCommunityDialog } from "@/components/community/edit-community-dialog"
import { MemberManagement } from "@/components/community/member-management"
import { CreatePost } from "@/components/post/create-post"
import { PostCard } from "@/components/post/post-card"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { ProtectedRoute } from "@/lib/protected-route"
import type { Community, Post } from "@/lib/types"

function CommunityDetailContent() {
  const { toast } = useToast()
  // const { user } = useAuth() // user is unused
  const router = useRouter()
  const params = useParams()
  const communityId = Number.parseInt(params.id as string)

  const [community, setCommunity] = useState<Community | null>(null)
  const [posts, setPosts] = useState<Post[]>([])
  const [isLoading, setIsLoading] = useState(true)
  const [isLoadingPosts, setIsLoadingPosts] = useState(false)
  const [isMember, setIsMember] = useState(false)

  const loadCommunityDetails = useCallback(async () => {
    setIsLoading(true)
    try {
      const data = await api.getCommunityDetails(communityId)
      setCommunity(data)
      setIsMember(data.is_member || false)
    } catch {
      toast({
        title: "Error",
        description: "Failed to load community details",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }, [communityId, toast])

  const loadCommunityPosts = useCallback(async () => {
    setIsLoadingPosts(true)
    try {
      const response = await api.getCommunityPosts(communityId)
      setPosts(response.posts || [])
    } catch {
      toast({
        title: "Error",
        description: "Failed to load posts",
        variant: "destructive",
      })
    } finally {
      setIsLoadingPosts(false)
    }
  }, [communityId, toast])

  useEffect(() => {
    if (communityId) {
      void loadCommunityDetails()
      void loadCommunityPosts()
    }
  }, [communityId, loadCommunityDetails, loadCommunityPosts])

  const handleToggleMembership = async () => {
    try {
      if (isMember) {
        await api.leaveCommunity(communityId)
        toast({
          title: "Left community",
          description: `You have left ${community?.name}`,
        })
        setIsMember(false)
      } else {
        await api.joinCommunity(communityId)
        toast({
          title: "Joined community",
          description: `You are now a member of ${community?.name}`,
        })
        setIsMember(true)
      }
      void loadCommunityDetails()
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to update membership",
        variant: "destructive",
      })
    }
  }

  const handleDeleteCommunity = async () => {
    if (!confirm("Are you sure you want to delete this community? This action cannot be undone."))
      return

    try {
      await api.deleteCommunity(communityId)
      toast({
        title: "Success",
        description: "Community deleted successfully",
      })
      router.push("/communities")
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to delete community",
        variant: "destructive",
      })
    }
  }

  const handlePostCreated = (newPost: Post) => {
    setPosts([newPost, ...posts])
  }

  const handleCommunityUpdated = (updatedCommunity: Community) => {
    setCommunity(updatedCommunity)
  }

  const isAdmin = community?.role_id === 1
  const isModerator = community?.role_id === 2

  if (isLoading) {
    return (
      <div className="flex min-h-screen items-center justify-center">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (!community) {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center gap-4">
        <p className="text-muted-foreground">Community not found</p>
        <Button asChild>
          <Link href="/communities">Back to Communities</Link>
        </Button>
      </div>
    )
  }

  return (
    <div className="bg-background min-h-screen">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <Button variant="ghost" size="sm" className="mb-4" asChild>
          <Link href="/communities">
            <ArrowLeft className="mr-2 h-4 w-4" />
            Back to Communities
          </Link>
        </Button>

        <Card className="mb-6">
          <CardHeader>
            <div className="flex items-start justify-between gap-4">
              <div className="flex-1">
                <div className="flex items-center gap-2">
                  <CardTitle className="text-2xl">{community.name}</CardTitle>
                  {community.privacy_id === 2 ? (
                    <Lock className="text-muted-foreground h-5 w-5" />
                  ) : (
                    <Unlock className="text-muted-foreground h-5 w-5" />
                  )}
                </div>
                <CardDescription className="mt-2">{community.description}</CardDescription>
                <div className="text-muted-foreground mt-4 flex items-center gap-4 text-sm">
                  <div className="flex items-center gap-1">
                    <Users className="h-4 w-4" />
                    <span>{community.member_count || 0} members</span>
                  </div>
                  {isAdmin && (
                    <div className="flex items-center gap-1 text-yellow-600">
                      <Settings className="h-4 w-4" />
                      <span>Admin</span>
                    </div>
                  )}
                  {isModerator && (
                    <div className="flex items-center gap-1 text-blue-600">
                      <Settings className="h-4 w-4" />
                      <span>Moderator</span>
                    </div>
                  )}
                </div>
              </div>
              <div className="flex flex-col gap-2">
                <Button
                  variant={isMember ? "outline" : "default"}
                  onClick={handleToggleMembership}
                  className="gap-2"
                >
                  {isMember && <Check className="h-4 w-4" />}
                  {isMember ? "Joined" : "Join"}
                </Button>
                {isAdmin && (
                  <>
                    <EditCommunityDialog
                      community={community}
                      onCommunityUpdated={handleCommunityUpdated}
                    />
                    <Button variant="destructive" size="sm" onClick={handleDeleteCommunity}>
                      <Trash2 className="mr-2 h-4 w-4" />
                      Delete
                    </Button>
                  </>
                )}
              </div>
            </div>
          </CardHeader>
        </Card>

        {isAdmin || isModerator ? (
          <Tabs defaultValue="feed" className="w-full">
            <TabsList className="grid w-full max-w-[400px] grid-cols-2">
              <TabsTrigger value="feed">Feed</TabsTrigger>
              <TabsTrigger value="members">Members</TabsTrigger>
            </TabsList>

            <TabsContent value="feed" className="mt-6 space-y-6">
              {isMember && (
                <CreatePost
                  onPostCreated={handlePostCreated}
                  defaultCommunityId={communityId}
                  hideCommunitySelect
                />
              )}

              {isLoadingPosts ? (
                <div className="flex items-center justify-center py-12">
                  <Loader2 className="h-8 w-8 animate-spin" />
                </div>
              ) : posts.length === 0 ? (
                <Card>
                  <CardContent className="text-muted-foreground py-12 text-center">
                    No posts yet. Be the first to post!
                  </CardContent>
                </Card>
              ) : (
                posts.map((post) => <PostCard key={post.post_id} post={post} />)
              )}
            </TabsContent>

            <TabsContent value="members" className="mt-6">
              <MemberManagement communityId={communityId} isAdmin={isAdmin} />
            </TabsContent>
          </Tabs>
        ) : (
          <div className="space-y-6">
            {isMember && (
              <CreatePost
                onPostCreated={handlePostCreated}
                defaultCommunityId={communityId}
                hideCommunitySelect
              />
            )}

            {isLoadingPosts ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin" />
              </div>
            ) : posts.length === 0 ? (
              <Card>
                <CardContent className="text-muted-foreground py-12 text-center">
                  No posts yet. {isMember ? "Be the first to post!" : "Join to see posts!"}
                </CardContent>
              </Card>
            ) : (
              posts.map((post) => <PostCard key={post.post_id} post={post} />)
            )}
          </div>
        )}
      </div>
    </div>
  )
}

export default function CommunityDetailPage() {
  return (
    <ProtectedRoute>
      <CommunityDetailContent />
    </ProtectedRoute>
  )
}
