import { Children, cloneElement, isValidElement, type ReactNode } from "react";

/** Preserve semantic emphasis, spaces and natural wrapping while revealing words. */
export default function MotionWords({ children }: { children: ReactNode }) {
  function split(nodes: ReactNode): ReactNode {
    return Children.map(nodes, (child) => {
      if (typeof child === "string") {
        return child.split(/(\s+)/).map((word, index) =>
          /^\s*$/.test(word) ? word : <span className="motion-word" key={index}>{word}</span>,
        );
      }
      if (isValidElement<{ children?: ReactNode }>(child)) return cloneElement(child, {}, split(child.props.children));
      return child;
    });
  }
  return <>{split(children)}</>;
}
