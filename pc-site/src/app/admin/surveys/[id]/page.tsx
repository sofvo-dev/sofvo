import ClientPage from "./ClientPage";

export function generateStaticParams() {
  return [{ id: "_" }];
}

export default function Page() {
  return <ClientPage />;
}
