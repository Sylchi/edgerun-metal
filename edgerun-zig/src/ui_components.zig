const object = @import("object.zig");
const ui = @import("ui.zig");
const component_common = @import("ui_component_common.zig");
const component_union = @import("ui/components/Component.zig");
const component_io = @import("ui/components/ComponentIO.zig");
const node_renderer = @import("ui/components/NodeRenderer.zig");
const tree_component = @import("ui/components/Tree.zig");
const stack_component = @import("ui/components/Stack.zig");
const slot_component = @import("ui/components/Slot.zig");
pub const layouts = @import("layouts.zig");

pub const Error = component_common.Error;

pub const Component = component_union.Component;

pub const RenderOptions = component_common.RenderOptions;
pub const Accessibility = component_common.Accessibility;
pub const AccessibilityNode = component_common.AccessibilityNode;
pub const AccessibilityTree = component_common.AccessibilityTree;

pub fn renderNode(scene: *ui.Scene, bounds: ui.Rect, node: ui.Node, options: RenderOptions) ui.RenderError!void {
    return node_renderer.renderNode(Component, scene, bounds, node, options);
}

pub fn accessibility(component: Component) Accessibility {
    return component.accessibility();
}

pub fn collectAccessibility(tree: *AccessibilityTree, bounds: ui.Rect, component: Component, options: RenderOptions) component_common.AccessibilityError!void {
    return component.collectAccessibility(tree, bounds, options);
}

pub fn measureNode(node: ui.Node, constraints: layouts.types.Constraints, options: RenderOptions) layouts.types.Measurement {
    return node_renderer.measureNode(Component, node, constraints, options);
}

pub const Stack = stack_component.Stack(Component);
pub const StackTree = stack_component.StackTree(Component);

pub const Slot = slot_component.Slot(Component);
pub const SlotTree = slot_component.SlotTree(Component);

pub const Tree = tree_component.Tree(Component);
pub const TreeObjects = tree_component.TreeObjects;

pub fn objectRequirements() object.Requirements {
    return component_io.requirements();
}

comptime {
    _ = @import("ui/components/ComponentTests.zig");
}
