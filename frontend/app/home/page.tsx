"use client"

import { useEffect, useState } from "react"
import Link from "next/link"
import { Hash, Loader2, Search, TrendingUp, UsersIcon } from "lucide-react"
import { CreatePost } from "@/components/post/create-post"
import { PostCard } from "@/components/post/post-card"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { withAuth } from "@/lib/protected-route"
import type { Community, Post, Recommendation, UserSearchResult } from "@/lib/types"

function HomePage() {
  const [activeTab, setActiveTab] = useState<"foryou" | "explore" | "search">("foryou")
  const [forYouPosts, setForYouPosts] = useState<Post[]>([])
  const [explorePosts, setExplorePosts] = useState<Post[]>([])
  const [searchPosts, setSearchPosts] = useState<Post[]>([])
  const [recommendations, setRecommendations] = useState<Recommendation[]>([])
  const [trendingHashtags, setTrendingHashtags] = useState<{ hashtag: string; count: number }[]>([])
  const [isLoading, setIsLoading] = useState(false)
  const [isLoadingRecs, setIsLoadingRecs] = useState(false)
  const [isLoadingTrending, setIsLoadingTrending] = useState(false)

  // Search state
  const [searchQuery, setSearchQuery] = useState("")
  const [userSearchResults, setUserSearchResults] = useState<UserSearchResult[]>([])
  const [communitySearchResults, setCommunitySearchResults] = useState<Community[]>([])

  const { toast } = useToast()

  const fetchPosts = async (tab: "foryou" | "explore" | "search") => {
    if (tab === "search") return // Search is handled separately

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

  const fetchTrendingHashtags = async () => {
    setIsLoadingTrending(true)
    try {
      const response = await api.getTrendingHashtags()
      if (response && response.hashtags) {
        setTrendingHashtags(response.hashtags)
      }
    } catch (e) {
      console.error("Failed to fetch trending hashtags", e)
    } finally {
      setIsLoadingTrending(false)
    }
  }

  // Handle live user and community search (dropdown)
  const handleUserSearch = async (query: string) => {
    setSearchQuery(query)
    if (query.trim().length < 2) {
      setUserSearchResults([])
      setCommunitySearchResults([])
      return
    }

    try {
      const [usersRes, commRes] = await Promise.all([
        api.searchUsers(query),
        api.searchCommunities(query),
      ])
      setUserSearchResults(usersRes.users)
      setCommunitySearchResults(commRes.communities)
    } catch (e) {
      console.error("Search failed:", e)
    }
  }

  // Handle full search (posts + switch tab)
  const executeSearch = async (query: string) => {
    if (!query.trim()) return

    setIsLoading(true)
    setActiveTab("search")
    setUserSearchResults([]) // Clear dropdown
    setCommunitySearchResults([])
    try {
      const response = await api.searchPosts(query)
      setSearchPosts(response.posts)
    } catch {
      toast({
        title: "Error",
        description: "Search failed. Please try again.",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  const handleHashtagClick = (hashtag: string) => {
    const query = `#${hashtag}`
    setSearchQuery(query)
    void executeSearch(query)
  }

  useEffect(() => {
    if (activeTab !== "search") {
      void fetchPosts(activeTab)
    }
    void fetchRecommendations()
    void fetchTrendingHashtags()
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [activeTab])

  const handleTabChange = (value: string) => {
    const newTab = value as "foryou" | "explore" | "search"
    setActiveTab(newTab)
  }

  const handleLikeUpdate = (postId: number, liked: boolean, newCount: number) => {
    const updatePosts = (posts: Post[]) =>
      posts.map((post) =>
        post.post_id === postId ? { ...post, liked_by_user: liked, like_count: newCount } : post
      )

    if (activeTab === "foryou") {
      setForYouPosts(updatePosts)
    } else if (activeTab === "explore") {
      setExplorePosts(updatePosts)
    } else {
      setSearchPosts(updatePosts)
    }
  }

  const handlePostCreated = (newPost: Post) => {
    if (activeTab === "foryou") {
      setForYouPosts((prev) => [newPost, ...prev])
    } else if (activeTab === "explore") {
      setExplorePosts((prev) => [newPost, ...prev])
    }
  }

  return (
    <div className="bg-background min-h-screen">
      <div className="mx-auto max-w-7xl px-4 py-6 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 gap-6 lg:grid-cols-3">
          {/* Main Feed */}
          <div className="space-y-6 lg:col-span-2">
            {/* Universal Search Bar */}
            <div className="relative">
              <Search className="text-muted-foreground absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2" />
              <Input
                type="text"
                placeholder="Search users, hashtags, or posts..."
                value={searchQuery}
                onChange={(e) => void handleUserSearch(e.target.value)}
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    void executeSearch(searchQuery)
                  }
                }}
                className="pl-9"
              />
              {/* Search Dropdown */}
              {(userSearchResults.length > 0 || communitySearchResults.length > 0) && (
                <div className="bg-card border-border absolute z-10 mt-1 max-h-[400px] w-full overflow-y-auto rounded-md border shadow-lg">
                  {/* Users Section */}
                  {userSearchResults.length > 0 && (
                    <>
                      <div className="text-muted-foreground px-3 py-2 text-xs font-semibold uppercase">
                        Users
                      </div>
                      {userSearchResults.map((result) => (
                        <Link
                          key={`user-${result.user_id}`}
                          href={`/profile/${result.username}`}
                          className="hover:bg-muted flex items-center gap-3 p-3 transition-colors"
                          onClick={() => {
                            setUserSearchResults([])
                            setCommunitySearchResults([])
                            setSearchQuery("")
                          }}
                        >
                          <Avatar className="h-8 w-8">
                            <AvatarImage src={result.profile_picture_url || "/placeholder.svg"} />
                            <AvatarFallback>{result.username[0].toUpperCase()}</AvatarFallback>
                          </Avatar>
                          <div className="min-w-0 flex-1">
                            <div className="font-medium">{result.username}</div>
                            {result.bio && (
                              <div className="text-muted-foreground truncate text-xs">
                                {result.bio}
                              </div>
                            )}
                          </div>
                        </Link>
                      ))}
                    </>
                  )}

                  {/* Separator if both exist */}
                  {userSearchResults.length > 0 && communitySearchResults.length > 0 && (
                    <div className="border-border my-1 border-t" />
                  )}

                  {/* Communities Section */}
                  {communitySearchResults.length > 0 && (
                    <>
                      <div className="text-muted-foreground px-3 py-2 text-xs font-semibold uppercase">
                        Communities
                      </div>
                      {communitySearchResults.map((comm) => (
                        <Link
                          key={`comm-${comm.id}`}
                          href={`/communities/${comm.id}`}
                          className="hover:bg-muted flex items-center gap-3 p-3 transition-colors"
                          onClick={() => {
                            setUserSearchResults([])
                            setCommunitySearchResults([])
                            setSearchQuery("")
                          }}
                        >
                          <div className="bg-primary/10 flex h-8 w-8 items-center justify-center rounded-full">
                            <UsersIcon className="text-primary h-4 w-4" />
                          </div>
                          <div className="min-w-0 flex-1">
                            <div className="font-medium">{comm.name}</div>
                            <div className="text-muted-foreground truncate text-xs">
                              {comm.member_count} members
                            </div>
                          </div>
                        </Link>
                      ))}
                    </>
                  )}
                </div>
              )}
            </div>

            <Tabs value={activeTab} onValueChange={handleTabChange} className="w-full">
              <TabsList className="mb-6 grid w-full grid-cols-2 lg:grid-cols-3">
                <TabsTrigger value="foryou" className="gap-2">
                  <UsersIcon className="h-4 w-4" />
                  For You
                </TabsTrigger>
                <TabsTrigger value="explore" className="gap-2">
                  <TrendingUp className="h-4 w-4" />
                  Explore
                </TabsTrigger>
                {/* Show Search Results tab if searching */}
                <TabsTrigger
                  value="search"
                  className={`gap-2 ${activeTab !== "search" ? "hidden lg:pointer-events-none lg:flex lg:opacity-50" : ""}`}
                  disabled={activeTab !== "search"}
                >
                  <Search className="h-4 w-4" />
                  Results
                </TabsTrigger>
              </TabsList>

              <TabsContent value="foryou" className="mt-0">
                <CreatePost onPostCreated={handlePostCreated} />
                <PostList
                  posts={forYouPosts}
                  isLoading={isLoading}
                  emptyMessage="No posts from people you follow yet."
                  onLikeUpdate={handleLikeUpdate}
                />
              </TabsContent>

              <TabsContent value="explore" className="mt-0">
                <CreatePost onPostCreated={handlePostCreated} />
                <PostList
                  posts={explorePosts}
                  isLoading={isLoading}
                  emptyMessage="No trending posts available right now."
                  onLikeUpdate={handleLikeUpdate}
                />
              </TabsContent>

              <TabsContent value="search" className="mt-0">
                <PostList
                  posts={searchPosts}
                  isLoading={isLoading}
                  emptyMessage="No posts found matching your search."
                  onLikeUpdate={handleLikeUpdate}
                />
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

            {/* Trending Topics */}
            <Card>
              <CardHeader>
                <CardTitle className="flex items-center gap-2">
                  <Hash className="h-5 w-5" />
                  Trending Topics
                </CardTitle>
                <CardDescription>Popular hashtags right now</CardDescription>
              </CardHeader>
              <CardContent>
                {isLoadingTrending ? (
                  <div className="flex justify-center py-4">
                    <Loader2 className="text-muted-foreground h-6 w-6 animate-spin" />
                  </div>
                ) : trendingHashtags.length > 0 ? (
                  <div className="space-y-3">
                    {trendingHashtags.map((item) => (
                      <button
                        key={item.hashtag}
                        onClick={() => handleHashtagClick(item.hashtag)}
                        className="group hover:bg-muted/50 flex w-full items-center justify-between rounded-md p-2 transition-colors"
                      >
                        <span className="group-hover:text-primary text-sm font-medium transition-colors">
                          #{item.hashtag}
                        </span>
                        <span className="text-muted-foreground text-xs">{item.count} posts</span>
                      </button>
                    ))}
                  </div>
                ) : (
                  <p className="text-muted-foreground py-4 text-center text-sm">
                    No trending topics using hashtags yet.
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

// Helper component to reduce duplication
function PostList({
  posts,
  isLoading,
  emptyMessage,
  onLikeUpdate,
}: {
  posts: Post[]
  isLoading: boolean
  emptyMessage: string
  onLikeUpdate: (id: number, liked: boolean, count: number) => void
}) {
  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="text-primary h-8 w-8 animate-spin" />
      </div>
    )
  }

  if (posts.length > 0) {
    return (
      <div className="space-y-4">
        {posts.map((post) => (
          <PostCard key={post.post_id} post={post} onLikeUpdate={onLikeUpdate} />
        ))}
      </div>
    )
  }

  return (
    <Card>
      <CardContent className="py-12 text-center">
        <Search className="text-muted-foreground mx-auto mb-4 h-12 w-12" />
        <p className="text-muted-foreground mb-4">{emptyMessage}</p>
      </CardContent>
    </Card>
  )
}

export default withAuth(HomePage)
