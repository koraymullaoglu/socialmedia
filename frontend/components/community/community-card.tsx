"use client"

import { useState } from "react"
import Link from "next/link"
import { Check, Lock, Unlock, Users } from "lucide-react"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import type { Community } from "@/lib/types"

interface CommunityCardProps {
  community: Community
  onMembershipChange?: (communityId: number, isMember: boolean) => void
}

export function CommunityCard({ community, onMembershipChange }: CommunityCardProps) {
  const { toast } = useToast()
  const [isMember, setIsMember] = useState(community.is_member || false)
  const [isLoading, setIsLoading] = useState(false)

  const handleToggleMembership = async () => {
    setIsLoading(true)
    try {
      if (isMember) {
        await api.leaveCommunity(community.id)
        toast({
          title: "Left community",
          description: `You have left ${community.name}`,
        })
      } else {
        await api.joinCommunity(community.id)
        toast({
          title: "Joined community",
          description: `You are now a member of ${community.name}`,
        })
      }
      const newMemberStatus = !isMember
      setIsMember(newMemberStatus)
      onMembershipChange?.(community.id, newMemberStatus)
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to update membership",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }

  return (
    <Link href={`/communities/${community.id}`} className="block">
      <Card className="transition-shadow hover:shadow-md">
        <CardHeader>
          <div className="flex items-start justify-between">
            <div className="flex-1">
              <CardTitle className="text-lg">{community.name}</CardTitle>
              <CardDescription className="mt-1 line-clamp-2">
                {community.description}
              </CardDescription>
            </div>
            {community.privacy_id === 2 ? (
              <Lock className="text-muted-foreground h-5 w-5" />
            ) : (
              <Unlock className="text-muted-foreground h-5 w-5" />
            )}
          </div>
        </CardHeader>
        <CardContent>
          <div className="flex items-center justify-between">
            <div className="text-muted-foreground flex items-center gap-1 text-sm">
              <Users className="h-4 w-4" />
              <span>{community.member_count || 0} members</span>
            </div>
            <Button
              variant={isMember ? "outline" : "default"}
              size="sm"
              onClick={(e) => {
                e.preventDefault()
                e.stopPropagation()
                void handleToggleMembership()
              }}
              disabled={isLoading}
              className="gap-2"
            >
              {isMember && <Check className="h-4 w-4" />}
              {isMember ? "Joined" : "Join"}
            </Button>
          </div>
        </CardContent>
      </Card>
    </Link>
  )
}
