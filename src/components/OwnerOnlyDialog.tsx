import {
  Dialog,
  DialogClose,
  DialogContent,
  DialogDescription,
  DialogFooter,
  DialogHeader,
  DialogTitle,
} from "./ui/dialog";
import { Button } from "./ui/button";

interface OwnerOnlyDialogProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
}

/** Shown when a public (unauthenticated) visitor tries to export data.
 * Reused across Reports/Journal/Ledger — see useExportGuard. */
export function OwnerOnlyDialog({ open, onOpenChange }: OwnerOnlyDialogProps) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent>
        <DialogHeader>
          <DialogTitle>Akses terbatas</DialogTitle>
          <DialogDescription>
            Export data cuma bisa diakses oleh pemilik akun. Tampilan ini demo
            publik — angka-angka yang ditampilkan sudah disamarkan untuk
            alasan privasi, jadi belum ada gunanya diexport.
          </DialogDescription>
        </DialogHeader>
        <DialogFooter>
          <DialogClose asChild>
            <Button variant="outline" size="sm">
              Tutup
            </Button>
          </DialogClose>
        </DialogFooter>
      </DialogContent>
    </Dialog>
  );
}
