"use client"

import { useCallback, useEffect, useState } from "react"
import Link from "next/link"
import { Crown, Loader2, Shield, UserIcon, UserMinus } from "lucide-react"
import { Avatar, AvatarFallback, AvatarImage } from "@/components/ui/avatar"
import { Button } from "@/components/ui/button"
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card"
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select"
import { useToast } from "@/hooks/use-toast"
import { api } from "@/lib/api"
import { useAuth } from "@/lib/auth-context"
import type { CommunityMember } from "@/lib/types"

interface MemberManagementProps {
  communityId: number
  isAdmin: boolean
}

export function MemberManagement({ communityId, isAdmin }: MemberManagementProps) {
  const { toast } = useToast()
  const { user } = useAuth()
  const [members, setMembers] = useState<CommunityMember[]>([])
  const [isLoading, setIsLoading] = useState(true)

  const loadMembers = useCallback(async () => {
    setIsLoading(true)
    try {
      const response = await api.getCommunityMembers(communityId)
      setMembers(response.members)
    } catch {
      toast({
        title: "Error",
        description: "Failed to load members",
        variant: "destructive",
      })
    } finally {
      setIsLoading(false)
    }
  }, [communityId, toast])

  useEffect(() => {
    void loadMembers()
  }, [loadMembers])

  const handleRemoveMember = async (userId: number, username: string) => {
    if (!confirm(`Are you sure you want to remove ${username}?`)) return

    try {
      await api.removeCommunityMember(communityId, userId)
      setMembers(members.filter((m) => m.user_id !== userId))
      toast({
        title: "Success",
        description: `${username} has been removed from the community`,
      })
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to remove member",
        variant: "destructive",
      })
    }
  }

  const handleChangeRole = async (userId: number, newRoleId: number, username: string) => {
    try {
      await api.changeMemberRole(communityId, userId, newRoleId)
      setMembers(members.map((m) => (m.user_id === userId ? { ...m, role_id: newRoleId } : m)))
      const roleName = newRoleId === 1 ? "Admin" : newRoleId === 2 ? "Moderator" : "Member"
      toast({
        title: "Success",
        description: `${username}'s role has been changed to ${roleName}`,
      })
    } catch (error) {
      toast({
        title: "Error",
        description: error instanceof Error ? error.message : "Failed to change role",
        variant: "destructive",
      })
    }
  }

  const getRoleIcon = (roleId: number) => {
    switch (roleId) {
      case 1:
        return <Crown className="h-4 w-4 text-yellow-500" />
      case 2:
        return <Shield className="h-4 w-4 text-blue-500" />
      default:
        return <UserIcon className="text-muted-foreground h-4 w-4" />
    }
  }

  const getRoleName = (roleId: number) => {
    switch (roleId) {
      case 1:
        return "Admin"
      case 2:
        return "Moderator"
      default:
        return "Member"
    }
  }

  if (isLoading) {
    return (
      <div className="flex items-center justify-center py-12">
        <Loader2 className="h-8 w-8 animate-spin" />
      </div>
    )
  }

  return (
    <Card>
      <CardHeader>
        <CardTitle>Members ({members.length})</CardTitle>
        <CardDescription>Manage community members and their roles</CardDescription>
      </CardHeader>
      <CardContent>
        <div className="space-y-4">
          {members.map((member) => (
            <div
              key={member.user_id}
              className="flex items-center justify-between gap-4 rounded-lg border p-4"
            >
              <Link href={`/profile/${member.username}`} className="flex flex-1 items-center gap-3">
                <Avatar className="h-10 w-10">
                  <AvatarImage
                    src={member.profile_picture_url || "/placeholder.svg"}
                    alt={member.username}
                  />
                  <AvatarFallback>{member.username[0].toUpperCase()}</AvatarFallback>
                </Avatar>
                <div className="flex-1">
                  <p className="font-medium">{member.username}</p>
                  <div className="text-muted-foreground flex items-center gap-1 text-sm">
                    {getRoleIcon(member.role_id)}
                    <span>{getRoleName(member.role_id)}</span>
                  </div>
                </div>
              </Link>

              {isAdmin && member.user_id !== user?.user_id && (
                <div className="flex items-center gap-2">
                  <Select
                    value={member.role_id.toString()}
                    onValueChange={(value) =>
                      handleChangeRole(member.user_id, Number.parseInt(value), member.username)
                    }
                  >
                    <SelectTrigger className="w-[140px]">
                      <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                      <SelectItem value="1">Admin</SelectItem>
                      <SelectItem value="2">Moderator</SelectItem>
                      <SelectItem value="3">Member</SelectItem>
                    </SelectContent>
                  </Select>
                  <Button
                    variant="ghost"
                    size="icon"
                    onClick={() => handleRemoveMember(member.user_id, member.username)}
                  >
                    <UserMinus className="h-4 w-4" />
                  </Button>
                </div>
              )}
            </div>
          ))}
        </div>
      </CardContent>
    </Card>
  )
}
