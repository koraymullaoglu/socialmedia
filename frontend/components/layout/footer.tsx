export function Footer() {
  return (
    <footer className="border-border bg-background border-t">
      <div className="mx-auto max-w-7xl px-4 py-12 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 gap-8 md:grid-cols-4">
          {/* Brand */}
          <div className="col-span-1 md:col-span-2">
            <div className="mb-4 flex items-center space-x-2">
              <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-gradient-to-br from-blue-500 to-cyan-500">
                <span className="text-lg font-bold text-white">S</span>
              </div>
              <span className="text-xl font-bold">SocialHub</span>
            </div>
            <p className="text-muted-foreground max-w-md text-sm">
              Connect with friends, share moments, and build communities. The social platform
              designed for meaningful connections.
            </p>
          </div>

          {/* Links Removed (Demo artifacts) */}
        </div>

        <div className="border-border mt-8 border-t pt-8">
          <p className="text-muted-foreground text-center text-sm">
            © {new Date().getFullYear()} SocialHub. All rights reserved.
          </p>
        </div>
      </div>
    </footer>
  )
}
