export async function apiGet(path: string) {
  const res = await fetch(`${process.env.NEXT_PUBLIC_API_BASE}${path}`, {
    method: "GET",
    credentials: "include",
  });
  if (!res.ok) throw new Error(`API error: ${res.status}`);
  return res.json();
}
