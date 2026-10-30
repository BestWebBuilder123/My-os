# App modules

Each app is stored in its own JavaScript module and can be edited independently.

Modules export:
- `render(api)`: returns the app's interface markup.
- `mount(root, api)`: attaches the app's behavior.

The desktop lazy-loads an app module when that app is opened. Keep app-specific features and supporting files beside that app's module. The shared desktop shell provides the window manager and compatibility services.
