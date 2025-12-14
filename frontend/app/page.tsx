"use client"

import { useEffect } from "react"
import { useRouter, useSearchParams } from "next/navigation"
import { Footer } from "@/components/layout/footer"
import { Hero } from "@/components/layout/hero"
import { useToast } from "@/hooks/use-toast"
import { useAuth } from "@/lib/auth-context"

export default function Home() {
  const searchParams = useSearchParams()
  const { toast } = useToast()
  const router = useRouter()
  const { user, isLoading } = useAuth()

  useEffect(() => {
    if (!isLoading && user) {
      router.push("/home")
    }
  }, [user, isLoading, router])

  useEffect(() => {
    const success = searchParams.get("success")
    if (success === "login") {
      toast({
        title: "Welcome back!",
        description: "You have successfully logged in.",
      })
    } else if (success === "register") {
      toast({
        title: "Welcome to SocialHub!",
        description: "Your account has been created successfully.",
      })
    }
  }, [searchParams, toast])

  if (isLoading) {
    return null
  }

  return (
    <main className="flex min-h-screen flex-col">
      <Hero />
      <Footer />
    </main>
  )
}
