"use client"

import { useState } from "react"
import { Search } from "lucide-react"
import { ConversationList } from "@/components/messages/conversation-list"
import { MessageView } from "@/components/messages/message-view"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Input } from "@/components/ui/input"
import { api } from "@/lib/api"
import { useAuth } from "@/lib/auth-context"
import type { UserSearchResult } from "@/lib/types"

export default function MessagesPage() {
  const { user } = useAuth()
  const [selectedUserId, setSelectedUserId] = useState<number | undefined>()
  const [selectedUsername, setSelectedUsername] = useState<string>("")
  const [selectedProfilePicture, setSelectedProfilePicture] = useState<string>("")
  const [searchQuery, setSearchQuery] = useState("")
  const [searchResults, setSearchResults] = useState<UserSearchResult[]>([])
  const [isSearching, setIsSearching] = useState(false)

  const handleSelectConversation = (userId: number, username: string, profilePicture?: string) => {
    setSelectedUserId(userId)
    setSelectedUsername(username)
    setSelectedProfilePicture(profilePicture || "")
    setSearchQuery("")
    setSearchResults([])
  }

  const handleSearch = async (query: string) => {
    setSearchQuery(query)
    if (query.trim().length < 2) {
      setSearchResults([])
      return
    }

    setIsSearching(true)
    try {
      const response = await api.searchUsers(query, 20, true)
      // Filter out current user from results
      setSearchResults(response.users.filter((u) => u.user_id !== user?.user_id))
    } catch (error) {
      console.error("Search failed:", error)
      setSearchResults([])
    } finally {
      setIsSearching(false)
    }
  }

  return (
    <div className="bg-background flex h-[calc(100vh-4rem)]">
      {/* Left sidebar - Conversations */}
      <div className="border-border w-full border-r md:w-80 lg:w-96">
        <div className="border-border border-b p-4">
          <div className="relative">
            <Search className="text-muted-foreground absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2" />
            <Input
              type="text"
              placeholder="Search followed users..."
              value={searchQuery}
              onChange={(e) => handleSearch(e.target.value)}
              className="pl-9"
            />
          </div>
          {searchQuery && (
            <div className="bg-card border-border mt-2 max-h-60 overflow-y-auto rounded-lg border">
              {isSearching ? (
                <div className="text-muted-foreground p-4 text-center text-sm">Searching...</div>
              ) : searchResults.length === 0 ? (
                <div className="text-muted-foreground p-4 text-center text-sm">No users found</div>
              ) : (
                searchResults.map((result) => (
                  <button
                    key={result.user_id}
                    onClick={() =>
                      handleSelectConversation(
                        result.user_id,
                        result.username,
                        result.profile_picture_url
                      )
                    }
                    className="hover:bg-muted flex w-full items-center gap-3 p-3 transition-colors"
                  >
                    <Avatar className="h-10 w-10">
                      <AvatarImage src={result.profile_picture_url || "/placeholder.svg"} />
                      <AvatarFallback>{result.username[0].toUpperCase()}</AvatarFallback>
                    </Avatar>
                    <div className="min-w-0 flex-1 text-left">
                      <div className="font-medium">{result.username}</div>
                      {result.bio && (
                        <div className="text-muted-foreground truncate text-sm">{result.bio}</div>
                      )}
                    </div>
                  </button>
                ))
              )}
            </div>
          )}
        </div>
        <ConversationList
          onSelectConversation={handleSelectConversation}
          selectedUserId={selectedUserId}
        />
      </div>

      {/* Right side - Message view */}
      <div className="hidden flex-1 md:block">
        {selectedUserId ? (
          <MessageView
            userId={selectedUserId}
            username={selectedUsername}
            profilePicture={selectedProfilePicture}
            onClose={() => {
              setSelectedUserId(undefined)
              setSelectedUsername("")
              setSelectedProfilePicture("")
            }}
          />
        ) : (
          <div className="flex h-full items-center justify-center">
            <div className="text-center">
              <div className="bg-muted mx-auto mb-4 flex h-16 w-16 items-center justify-center rounded-full">
                <Search className="text-muted-foreground h-8 w-8" />
              </div>
              <h3 className="text-foreground mb-2 text-lg font-semibold">Select a conversation</h3>
              <p className="text-muted-foreground text-sm">
                Choose from your existing conversations or search for users
              </p>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
