import { useEffect, useState } from "react";
import { api } from "../utils/api";

export function useAuth() {
  const [state, setState] = useState({ loading: true, loggedIn: false });

  useEffect(() => {
    let alive = true;
    api
      .me()
      .then((r) => alive && setState({ loading: false, loggedIn: r.logged_in }))
      .catch(() => alive && setState({ loading: false, loggedIn: false }));
    return () => {
      alive = false;
    };
  }, []);

  return state;
}
