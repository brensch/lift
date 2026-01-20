import { UserProvider, useUser } from "@/context/UserContext";
import { Login } from "@/components/Login";
import { Workout } from "@/components/Workout";

function AppContent() {
  const { username } = useUser();
  return username ? <Workout /> : <Login />;
}

function App() {
  return (
    <UserProvider>
      <AppContent />
    </UserProvider>
  );
}

export default App;
