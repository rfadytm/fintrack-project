import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { MemoryRouter } from "react-router-dom";
import { describe, expect, it } from "vitest";
import Navbar from "./Navbar";

describe("Navbar", () => {
  it("hides the links behind a single Menu button until opened", async () => {
    render(
      <MemoryRouter initialEntries={["/journal"]}>
        <Navbar />
      </MemoryRouter>
    );
    expect(screen.queryByText("Jurnal")).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole("button", { name: "Menu" }));
    expect(screen.getByText("Jurnal")).toBeInTheDocument();
  });

  it("marks the current route's link as active once the menu is open", async () => {
    render(
      <MemoryRouter initialEntries={["/journal"]}>
        <Navbar />
      </MemoryRouter>
    );
    await userEvent.click(screen.getByRole("button", { name: "Menu" }));
    const active = screen.getByText("Jurnal");
    const inactive = screen.getByText("Dashboard");
    expect(active).toHaveClass("font-semibold");
    expect(inactive).not.toHaveClass("font-semibold");
  });

  it("closes the menu after clicking a link", async () => {
    render(
      <MemoryRouter initialEntries={["/journal"]}>
        <Navbar />
      </MemoryRouter>
    );
    await userEvent.click(screen.getByRole("button", { name: "Menu" }));
    await userEvent.click(screen.getByText("Dashboard"));
    expect(screen.queryByText("Jurnal")).not.toBeInTheDocument();
  });
});
