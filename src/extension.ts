import * as vscode from 'vscode';
import * as fs from 'fs';

const WATCH_FILE = '/tmp/claude-terminal-focus';

/**
 * Focus a terminal by its shell process ID.
 */
async function focusTerminalByPid(targetPid: number, notify: boolean): Promise<boolean> {
    for (const terminal of vscode.window.terminals) {
        const pid = await terminal.processId;
        if (pid === targetPid) {
            terminal.show(false);
            if (notify) {
                vscode.window.showWarningMessage(`⚠️ Claude needs input in: ${terminal.name}`);
            }
            return true;
        }
    }
    return false;
}

/**
 * Focus a terminal by its name.
 */
function focusTerminalByName(name: string, notify: boolean): boolean {
    const terminal = vscode.window.terminals.find(t => t.name === name);
    if (terminal) {
        terminal.show(false);
        if (notify) {
            vscode.window.showWarningMessage(`⚠️ Claude needs input in: ${terminal.name}`);
        }
        return true;
    }
    return false;
}

/**
 * Focus a terminal by its 1-based index.
 */
function focusTerminalByIndex(index: number, notify: boolean): boolean {
    const terminals = vscode.window.terminals;
    if (index >= 1 && index <= terminals.length) {
        const terminal = terminals[index - 1];
        terminal.show(false);
        if (notify) {
            vscode.window.showWarningMessage(`⚠️ Claude needs input in: ${terminal.name}`);
        }
        return true;
    }
    return false;
}

export function activate(context: vscode.ExtensionContext) {
    console.log('Ahoy extension activated');

    if (!fs.existsSync(WATCH_FILE)) {
        fs.writeFileSync(WATCH_FILE, '');
    }

    const watcher = fs.watch(WATCH_FILE, async (eventType) => {
        if (eventType === 'change') {
            try {
                let content = fs.readFileSync(WATCH_FILE, 'utf8').trim();
                if (!content) return;

                // Check for :notify suffix to show VS Code notification
                const notify = content.includes(':notify');
                // Check for :silent suffix to skip notification
                const silent = content.includes(':silent');
                content = content.replace(':notify', '').replace(':silent', '');

                const showNotify = notify && !silent;

                if (content.startsWith('pid:')) {
                    const pidStr = content.slice(4);
                    // Support pid:12345:label:agentName format
                    const labelMatch = pidStr.match(/^(\d+):label:(.+)$/);
                    let pid: number;
                    let agentLabel: string | undefined;
                    if (labelMatch) {
                        pid = parseInt(labelMatch[1], 10);
                        agentLabel = labelMatch[2];
                    } else {
                        pid = parseInt(pidStr, 10);
                    }
                    if (!isNaN(pid)) {
                        const focused = await focusTerminalByPid(pid, false);
                        if (focused && showNotify && agentLabel) {
                            vscode.window.showWarningMessage(`⚠️ ${agentLabel} needs input`);
                        } else if (focused && showNotify) {
                            vscode.window.showWarningMessage(`⚠️ Claude needs input`);
                        }
                    }
                } else if (content.startsWith('index:')) {
                    const idx = parseInt(content.slice(6), 10);
                    if (!isNaN(idx)) focusTerminalByIndex(idx, showNotify);
                } else if (content.startsWith('name:')) {
                    focusTerminalByName(content.slice(5), showNotify);
                } else {
                    const num = parseInt(content, 10);
                    if (!isNaN(num)) await focusTerminalByPid(num, showNotify);
                }

                fs.writeFileSync(WATCH_FILE, '');
            } catch (err) {
                console.error('Ahoy error:', err);
            }
        }
    });

    const uriHandler = vscode.window.registerUriHandler({
        async handleUri(uri: vscode.Uri) {
            const params = new URLSearchParams(uri.query);
            const pid = params.get('pid');
            const name = params.get('name');
            const index = params.get('index');
            const notify = params.get('notify') === 'true';

            if (pid) {
                const p = parseInt(pid, 10);
                if (!isNaN(p)) await focusTerminalByPid(p, notify);
            } else if (name) {
                focusTerminalByName(name, notify);
            } else if (index) {
                const idx = parseInt(index, 10);
                if (!isNaN(idx)) focusTerminalByIndex(idx, notify);
            }
        }
    });

    const command = vscode.commands.registerCommand('ahoy.focusTerminal', async () => {
        const terminals = vscode.window.terminals;
        if (terminals.length === 0) {
            vscode.window.showInformationMessage('No terminals open');
            return;
        }

        const items = await Promise.all(terminals.map(async (t, i) => ({
            label: t.name,
            description: `Terminal ${i + 1} (PID: ${await t.processId})`
        })));

        const selected = await vscode.window.showQuickPick(items, {
            placeHolder: 'Select terminal to focus'
        });

        if (selected) {
            focusTerminalByName(selected.label, false);
        }
    });

    context.subscriptions.push(
        { dispose: () => watcher.close() },
        uriHandler,
        command
    );
}

export function deactivate() {
    try {
        if (fs.existsSync(WATCH_FILE)) {
            fs.unlinkSync(WATCH_FILE);
        }
    } catch {}
}
