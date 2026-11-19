import { Children, createContext, isValidElement, useContext } from 'react';
import type { ReactNode, TdHTMLAttributes } from 'react';

const ColumnLabels = createContext<readonly string[]>([]);

export function DataTable({ columns, children, caption, className = '' }: {
  columns: readonly string[]; children: ReactNode; caption?: string; className?: string;
}) {
  return <ColumnLabels.Provider value={columns}>
    <table role="table" className={`data-table responsive-table ${className}`}>
      {caption && <caption className="sr-only">{caption}</caption>}
      <thead role="rowgroup"><tr role="row">{columns.map((label, index) =>
        <th key={index} scope="col" role="columnheader">{label || <span className="sr-only">Thao tác</span>}</th>
      )}</tr></thead>
      <tbody role="rowgroup">{children}</tbody>
    </table>
  </ColumnLabels.Provider>;
}

// Each cell keeps its desktop header when a row stacks vertically on a phone.
export function DataRow({ children }: { children: ReactNode }) {
  const labels = useContext(ColumnLabels);
  return <tr role="row">{Children.map(children, (cell, index) => {
    if (!isValidElement<TdHTMLAttributes<HTMLTableCellElement>>(cell) || cell.type !== 'td') return cell;
    const { children: content, ...attributes } = cell.props;
    return <td {...attributes} role="cell" data-label={labels[index]}><div className="cell-value">{content}</div></td>;
  })}</tr>;
}
