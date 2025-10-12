export const metadata = { title: "AlgoDatta" };

export default function RootLayout({ children }) {
  return (
    <html lang="en">
      <body style={{fontFamily: 'Inter, system-ui, Arial', margin: 0}}>{children}</body>
    </html>
  );
}
