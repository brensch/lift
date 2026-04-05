import { type ButtonHTMLAttributes, forwardRef } from "react";
import { cva, type VariantProps } from "class-variance-authority";
import { cn } from "@/lib/utils";

const buttonVariants = cva(
  "inline-flex items-center justify-center rounded-[10px] font-semibold transition-transform duration-150 hover:-translate-y-0.5 active:translate-y-0 cursor-pointer",
  {
    variants: {
      variant: {
        default: "border border-border bg-transparent text-text",
        primary: "bg-primary border-primary text-on-primary",
        ghost: "border-transparent text-muted hover:text-text",
      },
      size: {
        default: "px-4 py-2.5 text-[0.95rem]",
        lg: "px-7 py-3.5 text-lg",
        sm: "px-3 py-2 text-sm",
      },
    },
    defaultVariants: {
      variant: "default",
      size: "default",
    },
  }
);

type ButtonProps = ButtonHTMLAttributes<HTMLButtonElement> &
  VariantProps<typeof buttonVariants>;

const Button = forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, ...props }, ref) => {
    return (
      <button
        className={cn(buttonVariants({ variant, size, className }))}
        ref={ref}
        {...props}
      />
    );
  }
);
Button.displayName = "Button";

export { Button, buttonVariants };
