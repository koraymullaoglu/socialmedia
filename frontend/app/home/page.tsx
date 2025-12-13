"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { Loader2, TrendingUp, UsersIcon } from "lucide-react"
import { CreatePost } from "@/components/post/create-post"
import { PostCard } from "@/components/post/post-card"
import { Avatar, AvatarFallback } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { withAuth } from "@/lib/protected-route"
import type { Post, Recommendation } from "@/lib/types"

function HomePage() {
  const [activeTab, setActiveTab] = useState<"foryou" | "explore">("foryou")
  const [forYouPosts, setForYouPosts] = useState<Post[]>([])
  const [explorePosts, setExplorePosts] = useState<Post[]>([])
  const [recommendations, setRecommendations] = useState<Recommendation[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [isLoadingRecs, setIsLoadingRecs] = useState(false)
  const { toast } = useToast()

  const fetchPosts = async (tab: "foryou" | "explore") => {
    setIsLoading(true)
    try {
      const response = tab === "foryou" ? await api.getFeed() : await api.getDiscoverPosts()

      if (tab === "foryou") {
        setForYouPosts(response.posts)
      } else {
        setExplorePosts(response.posts)
      }
    } catch {
      toast({
        title: "Error",
        description: "Failed to load posts. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  const fetchRecommendations = async () => {
    setIsLoadingRecs(true)
    try {
      const response = await api.getRecommendations()
      if (response && response.success) {
        setRecommendations(response.recommendations)
      }
    } catch (e) {
      console.error("Failed to fetch recommendations", e)
    } finally {
      setIsLoadingRecs(false)
    }
  }

  useEffect(() => {
    void fetchPosts(activeTab)
    void fetchRecommendations()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab])

  const handleTabChange = (value: string) => {
    const newTab = value as "foryou" | "explore"
    setActiveTab(newTab)
  }

  const handleLikeUpdate = (postId: number, liked: boolean, newCount: number) => {
    const updatePosts = (posts: Post[]) =>
      posts.map((post) =>
        post.post_id === postId ? { ...post, liked_by_user: liked, like_count: newCount } : post
      )

    if (activeTab === "foryou") {
      setForYouPosts(updatePosts)
    } else {
      setExplorePosts(updatePosts)
    }
  }

  const handlePostCreated = (newPost: Post) => {
    if (activeTab === "foryou") {
      setForYouPosts((prev) => [newPost, ...prev])
    } else {
      setExplorePosts((prev) => [newPost, ...prev])
    }
  }

  const currentPosts = activeTab === "foryou" ? forYouPosts : explorePosts

  return (
    <div className="bg-background min-h-screen">
      <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Main Feed */}
          <div className="lg:col-span-2">
            <Tabs value={activeTab} onValueChange={handleTabChange} className="w-full">
              <TabsList className="mb-6 grid w-full grid-cols-2">
                <TabsTrigger value="foryou" className="gap-2">
                  <UsersIcon className="h-4 w-4" />
                  For You
                </TabsTrigger>
                <TabsTrigger value="explore" className="gap-2">
                  <TrendingUp className="h-4 w-4" />
                  Explore
                </TabsTrigger>
              </TabsList>

              <TabsContent value="foryou" className="mt-0">
                <CreatePost onPostCreated={handlePostCreated} />

                {isLoading ? (
                  <div className="flex items-center justify-center py-12">
                    <Loader2 className="text-primary h-8 w-8 animate-spin" />
                  </div>
                ) : currentPosts.length > 0 ? (
                  <div className="space-y-4">
                    {currentPosts.map((post) => (
                      <PostCard key={post.post_id} post={post} onLikeUpdate={handleLikeUpdate} />
                    ))}
                  </div>
                ) : (
                  <Card>
                    <CardContent className="py-12 text-center">
                      <UsersIcon className="text-muted-foreground mx-auto mb-4 h-12 w-12" />
                      <p className="text-muted-foreground mb-4">
                        No posts from people you follow yet.
                      </p>
                      <Button onClick={() => setActiveTab("explore")}>Explore Posts</Button>
                    </CardContent>
                  </Card>
                )}
              </TabsContent>

              <TabsContent value="explore" className="mt-0">
                <CreatePost onPostCreated={handlePostCreated} />

                {isLoading ? (
                  <div className="flex items-center justify-center py-12">
                    <Loader2 className="text-primary h-8 w-8 animate-spin" />
                  </div>
                ) : currentPosts.length > 0 ? (
                  <div className="space-y-4">
                    {currentPosts.map((post) => (
                      <PostCard key={post.post_id} post={post} onLikeUpdate={handleLikeUpdate} />
                    ))}
                  </div>
                ) : (
                  <Card>
                    <CardContent className="py-12 text-center">
                      <TrendingUp className="text-muted-foreground mx-auto mb-4 h-12 w-12" />
                      <p className="text-muted-foreground">
                        No trending posts available right now.
                      </p>
                    </CardContent>
                  </Card>
                )}
              </TabsContent>
            </Tabs>
          </div>

          {/* Sidebar */}
          <div className="space-y-6">
            {/* Who to Follow */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <UsersIcon className="h-5 w-5" />
                  Who to Follow
                </CardTitle>
                <CardDescription>Suggested users for you</CardDescription>
              </CardHeader>
              <CardContent>
                {isLoadingRecs ? (
                  <div className="flex justify-center py-4">
                    <Loader2 className="text-muted-foreground h-6 w-6 animate-spin" />
                  </div>
                ) : recommendations.length > 0 ? (
                  <div className="space-y-4">
                    {recommendations.map((user) => (
                      <div
                        key={user.suggested_username}
                        className="flex items-center justify-between"
                      >
                        <div className="flex items-center gap-3">
                          <Avatar className="h-8 w-8">
                            <AvatarFallback>
                              {user.suggested_username[0].toUpperCase()}
                            </AvatarFallback>
                          </Avatar>
                          <div className="flex flex-col">
                            <span className="text-sm font-medium">{user.suggested_username}</span>
                            <span className="text-muted-foreground text-xs">
                              {user.mutual_count} mutual friends
                            </span>
                          </div>
                        </div>
                        <Button
                          size="sm"
                          variant="outline"
                          className="h-7 bg-transparent text-xs"
                          asChild
                        >
                          <Link href={`/profile/${user.suggested_username}`}>View</Link>
                        </Button>
                      </div>
                    ))}
                  </div>
                ) : (
                  <p className="text-muted-foreground py-4 text-center text-sm">
                    No suggestions available.
                  </p>
                )}
              </CardContent>
            </Card>
          </div>
        </div>
      </div>
    </div>
  )
}

export default withAuth(HomePage)
