"use client"

import { useCallback, useEffect, useState } from "react"
import { Loader2, Search } from "lucide-react"
import { CommunityCard } from "@/components/community/community-card"
import { CreateCommunityDialog } from "@/components/community/create-community-dialog"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card"
import { Input } from "@/components/ui/input"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { ProtectedRoute } from "@/lib/protected-route"
import type { Community } from "@/lib/types"

function CommunitiesPageContent() {
  const { toast } = useToast()
  const [allCommunities, setAllCommunities] = useState<Community[]>([])
  const [myCommunities, setMyCommunities] = useState<Community[]>([])
  const [searchQuery, setSearchQuery] = useState("")
  const [isLoadingAll, setIsLoadingAll] = useState(true)
  const [isLoadingMy, setIsLoadingMy] = useState(true)
  const [isSearching, setIsSearching] = useState(false)

  const loadAllCommunities = useCallback(async () => {
    setIsLoadingAll(true)
    try {
      const response = await api.getCommunities()
      setAllCommunities(response.communities || [])
    } catch {
      toast({
        title: "Error",
        description: "Failed to load communities",
        variant: "destructive",
      })
    } finally {
      setIsLoadingAll(false)
    }
  }, [toast])

  const loadMyCommunities = useCallback(async () => {
    setIsLoadingMy(true)
    try {
      const response = await api.getMyCommunities()
      setMyCommunities(response.communities || [])
    } catch {
      toast({
        title: "Error",
        description: "Failed to load your communities",
        variant: "destructive",
      })
    } finally {
      setIsLoadingMy(false)
    }
  }, [toast])

  useEffect(() => {
    void loadAllCommunities()
    void loadMyCommunities()
  }, [loadAllCommunities, loadMyCommunities])

  const handleSearch = async () => {
    if (!searchQuery.trim()) {
      void loadAllCommunities()
      return
    }

    setIsSearching(true)
    try {
      const response = await api.searchCommunities(searchQuery)
      setAllCommunities(response.communities || [])
    } catch {
      toast({
        title: "Error",
        description: "Failed to search communities",
        variant: "destructive",
      })
    } finally {
      setIsSearching(false)
    }
  }

  const handleMembershipChange = (communityId: number, isMember: boolean) => {
    if (isMember) {
      const community = allCommunities.find((c) => c.id === communityId)
      if (community && !myCommunities.find((c) => c.id === communityId)) {
        setMyCommunities([...myCommunities, { ...community, is_member: true }])
      }
    } else {
      setMyCommunities(myCommunities.filter((c) => c.id !== communityId))
    }

    setAllCommunities(
      allCommunities.map((c) => (c.id === communityId ? { ...c, is_member: isMember } : c))
    )
  }

  const handleCommunityCreated = (community: Community) => {
    setAllCommunities([community, ...allCommunities])
    setMyCommunities([{ ...community, is_member: true }, ...myCommunities])
  }

  return (
    <div className="bg-background min-h-screen">
      <div className="mx-auto max-w-6xl px-4 py-8 sm:px-6 lg:px-8">
        <div className="mb-8 flex flex-col gap-4 sm:flex-row sm:items-center sm:justify-between">
          <div>
            <h1 className="text-3xl font-bold">Communities</h1>
            <p className="text-muted-foreground mt-1">Discover and join communities</p>
          </div>
          <CreateCommunityDialog onCommunityCreated={handleCommunityCreated} />
        </div>

        <Tabs defaultValue="all" className="w-full">
          <TabsList className="grid w-full max-w-[400px] grid-cols-2">
            <TabsTrigger value="all">All Communities</TabsTrigger>
            <TabsTrigger value="my">My Communities</TabsTrigger>
          </TabsList>

          <TabsContent value="all" className="mt-6">
            <Card className="mb-6">
              <CardContent className="pt-6">
                <div className="flex gap-2">
                  <Input
                    placeholder="Search communities..."
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    onKeyDown={(e) => e.key === "Enter" && void handleSearch()}
                  />
                  <Button onClick={handleSearch} disabled={isSearching}>
                    {isSearching ? (
                      <Loader2 className="h-4 w-4 animate-spin" />
                    ) : (
                      <Search className="h-4 w-4" />
                    )}
                  </Button>
                </div>
              </CardContent>
            </Card>

            {isLoadingAll ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin" />
              </div>
            ) : allCommunities.length === 0 ? (
              <Card>
                <CardContent className="text-muted-foreground py-12 text-center">
                  No communities found
                </CardContent>
              </Card>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {allCommunities.map((community) => (
                  <CommunityCard
                    key={community.id}
                    community={community}
                    onMembershipChange={handleMembershipChange}
                  />
                ))}
              </div>
            )}
          </TabsContent>

          <TabsContent value="my" className="mt-6">
            {isLoadingMy ? (
              <div className="flex items-center justify-center py-12">
                <Loader2 className="h-8 w-8 animate-spin" />
              </div>
            ) : myCommunities.length === 0 ? (
              <Card>
                <CardHeader>
                  <CardTitle>No communities yet</CardTitle>
                </CardHeader>
                <CardContent className="text-muted-foreground">
                  Join communities to see them here, or create your own!
                </CardContent>
              </Card>
            ) : (
              <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-3">
                {myCommunities.map((community) => (
                  <CommunityCard
                    key={community.id}
                    community={community}
                    onMembershipChange={handleMembershipChange}
                  />
                ))}
              </div>
            )}
          </TabsContent>
        </Tabs>
      </div>
    </div>
  )
}

export default function CommunitiesPage() {
  return (
    <ProtectedRoute>
      <CommunitiesPageContent />
    </ProtectedRoute>
  )
}
