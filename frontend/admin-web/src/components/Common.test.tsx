import { fireEvent, render, screen } from '@testing-library/react';
import { expect, it, vi } from 'vitest';
import { Drawer } from './Common';
import { ConfirmationProvider, useConfirmation } from './ConfirmationDialog';

it('contains keyboard focus, preserves focus across renders, and restores the trigger', () => {
  const trigger = document.createElement('button');
  document.body.append(trigger); trigger.focus();
  const close = vi.fn();
  const { rerender, unmount } = render(<Drawer title="Hồ sơ" onClose={close}><input aria-label="Ghi chú" /><button>Lưu</button></Drawer>);
  const field = screen.getByLabelText('Ghi chú');
  field.focus();
  rerender(<Drawer title="Hồ sơ" onClose={() => close()}><input aria-label="Ghi chú" /><button>Lưu</button></Drawer>);
  expect(document.activeElement).toBe(field);
  screen.getByRole('button', { name: 'Lưu' }).focus();
  fireEvent.keyDown(document, { key: 'Tab' });
  expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Đóng' }));
  fireEvent.keyDown(document, { key: 'Tab', shiftKey: true });
  expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Lưu' }));
  unmount();
  expect(document.activeElement).toBe(trigger);
  trigger.remove();
});

it('blocks dismissal while a mutation is pending', () => {
  const close = vi.fn();
  render(<Drawer title="Đang lưu" busy onClose={close}><p>Xin chờ</p></Drawer>);
  fireEvent.keyDown(document, { key: 'Escape' });
  fireEvent.mouseDown(screen.getByRole('dialog').parentElement!);
  expect(close).not.toHaveBeenCalled();
  expect((screen.getByRole('button', { name: 'Đóng' }) as HTMLButtonElement).disabled).toBe(true);
});

it('keeps keyboard focus in the confirmation and dismisses only the top dialog', async () => {
  const close = vi.fn();
  function Review() {
    const confirm = useConfirmation();
    return <Drawer title="Hồ sơ" onClose={close}>
      <button onClick={() => void confirm({ title: 'Duyệt hồ sơ?', message: 'Kiểm tra thông tin', confirmLabel: 'Duyệt' })}>
        Xem quyết định
      </button>
    </Drawer>;
  }
  render(<ConfirmationProvider><Review /></ConfirmationProvider>);
  const trigger = screen.getByRole('button', { name: 'Xem quyết định' });
  trigger.focus();
  fireEvent.click(trigger);
  expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Quay lại' }));
  fireEvent.keyDown(document.activeElement!, { key: 'Tab' });
  expect(document.activeElement).toBe(screen.getByRole('button', { name: 'Duyệt' }));
  fireEvent.keyDown(document.activeElement!, { key: 'Escape' });
  expect(screen.queryByRole('alertdialog')).toBeNull();
  expect(document.activeElement).toBe(trigger);
  expect(close).not.toHaveBeenCalled();
});
