import { render, screen } from "@testing-library/react";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import Navbar from "./Navbar";

describe("Navbar", () => {
  it("marks the current route's link as active", () => {
    render(
      <MemoryRouter initialEntries={["/journal"]}>
        <Navbar />
      </MemoryRouter>
    );
    const active = screen.getByText("Jurnal");
    const inactive = screen.getByText("Dashboard");
    expect(active).toHaveClass("font-semibold");
    expect(inactive).not.toHaveClass("font-semibold");
  });
});
