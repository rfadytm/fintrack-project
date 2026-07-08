import { Component, type ErrorInfo, type ReactNode } from "react";
import { Card, CardContent } from "./ui/card";
import { Button } from "./ui/button";

interface Props {
  children: ReactNode;
}

interface State {
  error: Error | null;
}

// Blindspot fix: previously any render-time exception blanked the whole app
// with no feedback. This catches it and offers a reload instead of a white screen.
export class ErrorBoundary extends Component<Props, State> {
  state: State = { error: null };

  static getDerivedStateFromError(error: Error): State {
    return { error };
  }

  componentDidCatch(error: Error, info: ErrorInfo) {
    console.error("Unhandled render error:", error, info.componentStack);
  }

  render() {
    if (this.state.error) {
      return (
        <div className="min-h-screen flex items-center justify-center p-6 bg-gradient-to-br from-slate-50 via-blue-50/40 to-indigo-50">
          <Card className="max-w-md text-center">
            <CardContent className="flex flex-col items-center gap-3">
              <p className="text-2xl">⚠️</p>
              <h2 className="text-navy font-semibold text-lg">Terjadi kesalahan</h2>
              <p className="text-muted text-sm">{this.state.error.message}</p>
              <Button onClick={() => window.location.reload()}>Muat ulang</Button>
            </CardContent>
          </Card>
        </div>
      );
    }
    return this.props.children;
  }
}
