import { useState } from "react";
import { Button } from "@/components/ui/button";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import { useUser } from "@/context/UserContext";

export function Login() {
  const [inputUsername, setInputUsername] = useState("");
  const { setUsername } = useUser();

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (inputUsername.trim()) {
      setUsername(inputUsername.trim().toLowerCase());
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-background p-4">
      <Card className="w-full max-w-md">
        <CardHeader className="text-center">
          <CardTitle className="text-3xl font-bold">🏋️ Lift</CardTitle>
          <CardDescription>
            Social 5x5 Workout Tracker
          </CardDescription>
        </CardHeader>
        <CardContent>
          <form onSubmit={handleSubmit} className="space-y-4">
            <div className="space-y-2">
              <Label htmlFor="username">Username</Label>
              <Input
                id="username"
                type="text"
                placeholder="Enter your username"
                value={inputUsername}
                onChange={(e) => setInputUsername(e.target.value)}
                autoFocus
              />
            </div>
            <Button type="submit" className="w-full" disabled={!inputUsername.trim()}>
              Start Lifting
            </Button>
          </form>
          <p className="text-xs text-muted-foreground text-center mt-4">
            No account needed. Just pick a username and start tracking!
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
