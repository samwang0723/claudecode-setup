# React & Next.js Patterns

## Server Components (Default in App Router)

```tsx
// app/users/page.tsx — Server Component (no "use client" directive)
// Can directly access DB, env vars, file system
import { db } from "@/_lib/db";

export default async function UsersPage() {
  const users = await db.query<User>("SELECT * FROM users ORDER BY created_at DESC LIMIT 20");

  return (
    <main>
      <h1>Users</h1>
      <UserList users={users} />
    </main>
  );
}

// Rules:
// - No useState, useEffect, event handlers, or browser APIs
// - CAN: async/await, direct DB access, env vars, fs operations
// - Pass serializable props to Client Components
// - Fetch data here, not in Client Components (avoid waterfalls)
```

---

## Client Components

```tsx
"use client";

// Only add "use client" when you need:
// - useState, useEffect, useRef
// - Event handlers (onClick, onChange, etc.)
// - Browser APIs (window, document, localStorage)
// - Third-party client libraries

import { useState, useTransition } from "react";

type UserListProps = {
  readonly users: readonly User[];
};

export function UserList({ users }: UserListProps) {
  const [filter, setFilter] = useState("");
  const filtered = users.filter((u) =>
    u.name.toLowerCase().includes(filter.toLowerCase()),
  );

  return (
    <div>
      <input
        type="text"
        value={filter}
        onChange={(e) => setFilter(e.target.value)}
        placeholder="Filter users..."
      />
      <ul>
        {filtered.map((user) => (
          <UserCard key={user.id} user={user} />
        ))}
      </ul>
    </div>
  );
}
```

---

## Server Actions

```tsx
// _lib/actions.ts
"use server";

import { revalidatePath } from "next/cache";
import { z } from "zod";

const CreateUserSchema = z.object({
  name: z.string().min(1).max(100),
  email: z.string().email(),
});

export async function createUser(formData: FormData) {
  const result = CreateUserSchema.safeParse({
    name: formData.get("name"),
    email: formData.get("email"),
  });

  if (!result.success) {
    return { error: result.error.flatten().fieldErrors };
  }

  await db.query("INSERT INTO users (name, email) VALUES ($1, $2)", [
    result.data.name,
    result.data.email,
  ]);

  revalidatePath("/users");
  return { success: true };
}

// In component
export function CreateUserForm() {
  return (
    <form action={createUser}>
      <input name="name" required />
      <input name="email" type="email" required />
      <button type="submit">Create</button>
    </form>
  );
}
```

### Server Actions with useActionState

```tsx
"use client";

import { useActionState } from "react";
import { createUser } from "@/_lib/actions";

type ActionState = {
  error?: Record<string, string[]>;
  success?: boolean;
};

export function CreateUserForm() {
  const [state, formAction, isPending] = useActionState<ActionState, FormData>(
    async (_prev, formData) => createUser(formData),
    {},
  );

  return (
    <form action={formAction}>
      <input name="name" required />
      {state.error?.name && <p className="text-red-500">{state.error.name[0]}</p>}

      <input name="email" type="email" required />
      {state.error?.email && <p className="text-red-500">{state.error.email[0]}</p>}

      <button type="submit" disabled={isPending}>
        {isPending ? "Creating..." : "Create User"}
      </button>
    </form>
  );
}
```

---

## Custom Hooks

```tsx
// Encapsulate reusable stateful logic
function useDebounce<T>(value: T, delayMs: number): T {
  const [debounced, setDebounced] = useState(value);

  useEffect(() => {
    const timer = setTimeout(() => setDebounced(value), delayMs);
    return () => clearTimeout(timer);
  }, [value, delayMs]);

  return debounced;
}

// Fetch hook with loading/error state
function useFetch<T>(url: string) {
  const [state, setState] = useState<RequestState<T>>({ status: "idle" });

  useEffect(() => {
    const controller = new AbortController();
    setState({ status: "loading" });

    fetch(url, { signal: controller.signal })
      .then((res) => {
        if (!res.ok) throw new Error(`HTTP ${res.status}`);
        return res.json() as Promise<T>;
      })
      .then((data) => setState({ status: "success", data }))
      .catch((err) => {
        if (err.name !== "AbortError") {
          setState({ status: "error", error: err });
        }
      });

    return () => controller.abort();
  }, [url]);

  return state;
}

// LocalStorage hook with SSR safety
function useLocalStorage<T>(key: string, initialValue: T): [T, (value: T | ((prev: T) => T)) => void] {
  const [stored, setStored] = useState<T>(() => {
    if (typeof window === "undefined") return initialValue;
    try {
      const item = window.localStorage.getItem(key);
      return item ? (JSON.parse(item) as T) : initialValue;
    } catch {
      return initialValue;
    }
  });

  const setValue = useCallback(
    (value: T | ((prev: T) => T)) => {
      setStored((prev) => {
        const next = value instanceof Function ? value(prev) : value;
        window.localStorage.setItem(key, JSON.stringify(next));
        return next;
      });
    },
    [key],
  );

  return [stored, setValue];
}
```

---

## Component Patterns

### Compound Components

```tsx
type TabsContextValue = {
  activeTab: string;
  setActiveTab: (id: string) => void;
};

const TabsContext = createContext<TabsContextValue | null>(null);

function useTabs() {
  const ctx = useContext(TabsContext);
  if (!ctx) throw new Error("useTabs must be used within <Tabs>");
  return ctx;
}

function Tabs({ defaultTab, children }: { defaultTab: string; children: React.ReactNode }) {
  const [activeTab, setActiveTab] = useState(defaultTab);
  return (
    <TabsContext value={{ activeTab, setActiveTab }}>
      {children}
    </TabsContext>
  );
}

function TabList({ children }: { children: React.ReactNode }) {
  return <div role="tablist">{children}</div>;
}

function Tab({ id, children }: { id: string; children: React.ReactNode }) {
  const { activeTab, setActiveTab } = useTabs();
  return (
    <button
      role="tab"
      aria-selected={activeTab === id}
      onClick={() => setActiveTab(id)}
    >
      {children}
    </button>
  );
}

function TabPanel({ id, children }: { id: string; children: React.ReactNode }) {
  const { activeTab } = useTabs();
  if (activeTab !== id) return null;
  return <div role="tabpanel">{children}</div>;
}

// Usage
<Tabs defaultTab="profile">
  <TabList>
    <Tab id="profile">Profile</Tab>
    <Tab id="settings">Settings</Tab>
  </TabList>
  <TabPanel id="profile"><ProfileSection /></TabPanel>
  <TabPanel id="settings"><SettingsSection /></TabPanel>
</Tabs>
```

### Polymorphic Components

```tsx
type ButtonProps<T extends React.ElementType = "button"> = {
  as?: T;
  variant?: "primary" | "secondary" | "ghost";
  size?: "sm" | "md" | "lg";
  children: React.ReactNode;
} & Omit<React.ComponentPropsWithoutRef<T>, "as" | "variant" | "size" | "children">;

function Button<T extends React.ElementType = "button">({
  as,
  variant = "primary",
  size = "md",
  children,
  className,
  ...props
}: ButtonProps<T>) {
  const Component = as ?? "button";
  return (
    <Component
      className={cn(styles[variant], styles[size], className)}
      {...props}
    >
      {children}
    </Component>
  );
}

// Usage
<Button onClick={handleClick}>Click me</Button>
<Button as="a" href="/about">About</Button>
<Button as={Link} to="/dashboard">Dashboard</Button>
```

---

## Data Fetching Patterns (Next.js)

### Parallel Data Fetching

```tsx
// GOOD: Parallel fetches in Server Component
export default async function DashboardPage() {
  // These run in parallel — no waterfall
  const [user, orders, stats] = await Promise.all([
    getUser(),
    getRecentOrders(),
    getDashboardStats(),
  ]);

  return (
    <Dashboard user={user} orders={orders} stats={stats} />
  );
}

// BAD: Sequential waterfall
export default async function DashboardPage() {
  const user = await getUser();           // Wait...
  const orders = await getRecentOrders(); // Then wait...
  const stats = await getDashboardStats(); // Then wait...
}
```

### Streaming with Suspense

```tsx
import { Suspense } from "react";

export default function DashboardPage() {
  return (
    <main>
      <h1>Dashboard</h1>
      <Suspense fallback={<UserSkeleton />}>
        <UserSection />
      </Suspense>
      <Suspense fallback={<OrdersSkeleton />}>
        <RecentOrders />
      </Suspense>
    </main>
  );
}

// Each section is an async Server Component
async function UserSection() {
  const user = await getUser(); // Streams when ready
  return <UserCard user={user} />;
}

async function RecentOrders() {
  const orders = await getRecentOrders(); // Streams independently
  return <OrderTable orders={orders} />;
}
```

---

## Performance Patterns

### Memoization

```tsx
// useMemo — expensive computation
const sortedUsers = useMemo(
  () => [...users].sort((a, b) => a.name.localeCompare(b.name)),
  [users],
);

// useCallback — stable function reference for child components
const handleDelete = useCallback(
  (id: string) => {
    setUsers((prev) => prev.filter((u) => u.id !== id));
  },
  [],
);

// memo — skip re-render when props unchanged
const UserCard = memo(function UserCard({ user }: { user: User }) {
  return <div>{user.name}</div>;
});

// AVOID: Memoizing everything (overhead > benefit for simple ops)
// Only memoize when: expensive computation, large lists, or preventing cascading re-renders
```

### Virtualized Lists

```tsx
import { useVirtualizer } from "@tanstack/react-virtual";

function VirtualList({ items }: { items: readonly Item[] }) {
  const parentRef = useRef<HTMLDivElement>(null);

  const virtualizer = useVirtualizer({
    count: items.length,
    getScrollElement: () => parentRef.current,
    estimateSize: () => 48,
  });

  return (
    <div ref={parentRef} style={{ height: "400px", overflow: "auto" }}>
      <div style={{ height: `${virtualizer.getTotalSize()}px`, position: "relative" }}>
        {virtualizer.getVirtualItems().map((virtualItem) => (
          <div
            key={virtualItem.key}
            style={{
              position: "absolute",
              top: 0,
              transform: `translateY(${virtualItem.start}px)`,
              height: `${virtualItem.size}px`,
              width: "100%",
            }}
          >
            <ItemRow item={items[virtualItem.index]} />
          </div>
        ))}
      </div>
    </div>
  );
}
```

---

## Quick Reference — Do/Don't

| Do | Don't |
|-----|-------|
| Server Components by default | `"use client"` everywhere |
| `Promise.all` for parallel fetches | Sequential awaits (waterfall) |
| Server Actions for mutations | API routes for simple forms |
| `useActionState` for form state | Manual loading/error state |
| Suspense boundaries for streaming | Loading states in every component |
| `readonly` props | Mutable prop types |
| `memo` only when measured | Premature memoization |
| `useCallback` for child stability | `useCallback` on every function |
| Composition over inheritance | Deep component hierarchies |
| Co-locate related code | Split by file type (`components/`, `hooks/`, `utils/`) |
