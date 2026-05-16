import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import '../services/app_state.dart';
import '../models/ai_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _keywordController = TextEditingController();
  final _syncMinutesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Controllers will be populated in didChangeDependencies
    // after appState is available via Provider
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final appState = Provider.of<AppState>(context, listen: false);
    if (_usernameController.text.isEmpty && appState.hasFeedbinCredentials) {
      _usernameController.text = appState.feedbinUsername ?? '';
      _passwordController.text = appState.feedbinPassword ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, appState, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Feedbin Account
                _buildSectionTitle(context, 'Feedbin Account'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        TextField(
                          controller: _usernameController,
                          decoration: const InputDecoration(
                            labelText: 'Username / Email',
                            prefixIcon: Icon(Icons.person),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  if (_usernameController.text.isNotEmpty &&
                                      _passwordController.text.isNotEmpty) {
                                    appState.setFeedbinCredentials(
                                      _usernameController.text,
                                      _passwordController.text,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Credentials saved')),
                                    );
                                  }
                                },
                                icon: const Icon(Icons.save),
                                label: const Text('Save Credentials'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  if (_usernameController.text.isNotEmpty &&
                                      _passwordController.text.isNotEmpty) {
                                    appState.setFeedbinCredentials(
                                      _usernameController.text,
                                      _passwordController.text,
                                    );
                                    final ok = await appState.testFeedbinConnection();
                                    if (ok) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Connection successful! Syncing now...'),
                                          backgroundColor: Colors.green,
                                        ),
                                      );
                                      await appState.syncFeeds();
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(appState.error ?? 'Connection failed'),
                                          backgroundColor: Colors.red,
                                        ),
                                      );
                                    }
                                  }
                                },
                                icon: const Icon(Icons.wifi_tethering),
                                label: const Text('Test & Sync'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (appState.hasFeedbinCredentials) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.check_circle, color: Colors.green, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                'Connected',
                                style: TextStyle(color: Colors.green[700]),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Reading & Sync Behavior
                _buildSectionTitle(context, 'Reading & Sync'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text('Sync on startup'),
                        subtitle: const Text('Automatically fetch feeds when app starts'),
                        value: appState.syncOnStartup,
                        onChanged: (v) => appState.setSyncOnStartup(v),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Mark as read when scrolling'),
                        subtitle: const Text('Automatically mark articles as read when you view them'),
                        value: appState.markReadOnScroll,
                        onChanged: (v) => appState.setMarkReadOnScroll(v),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Auto-sync interval'),
                        subtitle: Text(appState.autoSyncMinutes > 0
                            ? 'Every ${appState.autoSyncMinutes} minutes'
                            : 'Disabled'),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            controller: _syncMinutesController..text = appState.autoSyncMinutes.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              suffixText: 'min',
                              isDense: true,
                            ),
                            onSubmitted: (val) {
                              final mins = int.tryParse(val) ?? 0;
                              appState.setAutoSyncMinutes(mins);
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Default sort order'),
                        subtitle: Text(appState.sortOrder.name[0].toUpperCase() + appState.sortOrder.name.substring(1)),
                        trailing: DropdownButton<SortOrder>(
                          value: appState.sortOrder,
                          items: const [
                            DropdownMenuItem(value: SortOrder.newest, child: Text('Newest first')),
                            DropdownMenuItem(value: SortOrder.oldest, child: Text('Oldest first')),
                            DropdownMenuItem(value: SortOrder.hottest, child: Text('Hottest first')),
                          ],
                          onChanged: (v) {
                            if (v != null) appState.setSortOrder(v);
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Read articles limit'),
                        subtitle: Text('${appState.readDaysLimit} days'),
                        trailing: SizedBox(
                          width: 80,
                          child: TextField(
                            controller: TextEditingController()..text = appState.readDaysLimit.toString(),
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              suffixText: 'days',
                              isDense: true,
                            ),
                            onSubmitted: (val) {
                              final days = int.tryParse(val) ?? 7;
                              appState.setReadDaysLimit(days);
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        title: const Text('Startup page'),
                        subtitle: Text(appState.startupPage),
                        trailing: DropdownButton<String>(
                          value: appState.startupPage,
                          items: const [
                            DropdownMenuItem(value: 'feeds', child: Text('Feeds')),
                            DropdownMenuItem(value: 'unread', child: Text('All Unread')),
                            DropdownMenuItem(value: 'read', child: Text('All Read')),
                            DropdownMenuItem(value: 'favorites', child: Text('Favorites')),
                          ],
                          onChanged: (v) {
                            if (v != null) appState.setStartupPage(v);
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // AI Providers
                _buildSectionTitle(context, 'AI Providers'),
                ...appState.aiProviders.map((provider) => _buildProviderCard(provider, appState, context)),
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddProviderDialog(context, appState),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Provider'),
                ),

                const SizedBox(height: 24),

                // Keyword Filters
                _buildSectionTitle(context, 'Keyword Filters'),
                const Padding(
                  padding: EdgeInsets.only(left: 16, right: 16, bottom: 8),
                  child: Text(
                    'Articles containing these keywords will be automatically marked as read:',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      ...appState.filterKeywords.map((keyword) => Chip(
                        label: Text(keyword),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () => appState.removeFilterKeyword(keyword),
                      )),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _keywordController,
                          decoration: const InputDecoration(
                            labelText: 'Add keyword',
                            hintText: 'e.g. sponsored, deal',
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle),
                        onPressed: () {
                          if (_keywordController.text.isNotEmpty) {
                            appState.addFilterKeyword(_keywordController.text);
                            _keywordController.clear();
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Data Management
                _buildSectionTitle(context, 'Data Management'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('Export Settings'),
                        subtitle: const Text('Save configuration to JSON file'),
                        onTap: () => _exportSettingsToFile(context, appState),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.upload),
                        title: const Text('Import Settings'),
                        subtitle: const Text('Restore from JSON file'),
                        onTap: () => _importSettingsFromFile(context, appState),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.description),
                        title: const Text('View Log File'),
                        subtitle: Text(appState.logger.logFilePath ?? 'No log file'),
                        onTap: () => _showLogViewer(context, appState),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // About
                _buildSectionTitle(context, 'About'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('NowRSS'),
                    subtitle: const Text('Version 0.3.0'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildProviderCard(AIProvider provider, AppState appState, BuildContext context) {
    final isDefault = appState.defaultProvider?.id == provider.id;
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.psychology,
          color: isDefault ? Colors.amber : null,
        ),
        title: Text(provider.name),
        subtitle: Text('${provider.type} \u00b7 ${provider.model}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isDefault)
              const Chip(
                label: Text('Default'),
                visualDensity: VisualDensity.compact,
              ),
            IconButton(
              icon: const Icon(Icons.edit, size: 20),
              onPressed: () => _showEditProviderDialog(context, provider, appState),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddProviderDialog(BuildContext context, AppState appState) {
    final nameController = TextEditingController();
    final urlController = TextEditingController(text: 'https://api.ollama.com/v1');
    final keyController = TextEditingController();
    final modelController = TextEditingController(text: 'llama3.2');
    String type = 'ollama';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add AI Provider'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI / Compatible')),
                ],
                onChanged: (value) => type = value!,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Base URL')),
              const SizedBox(height: 8),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'API Key (optional)'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final provider = AIProvider(
                id: DateTime.now().millisecondsSinceEpoch.toString(),
                name: nameController.text,
                type: type,
                baseUrl: urlController.text,
                apiKey: keyController.text,
                model: modelController.text,
              );
              appState.aiProviders.add(provider);
              appState.saveSettings();
              Navigator.pop(context);
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _showEditProviderDialog(BuildContext context, AIProvider provider, AppState appState) {
    final nameController = TextEditingController(text: provider.name);
    final urlController = TextEditingController(text: provider.baseUrl);
    final keyController = TextEditingController(text: provider.apiKey);
    final modelController = TextEditingController(text: provider.model);
    String type = provider.type;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit AI Provider'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: type,
                items: const [
                  DropdownMenuItem(value: 'ollama', child: Text('Ollama')),
                  DropdownMenuItem(value: 'openai', child: Text('OpenAI / Compatible')),
                ],
                onChanged: (value) => type = value!,
                decoration: const InputDecoration(labelText: 'Type'),
              ),
              const SizedBox(height: 8),
              TextField(controller: urlController, decoration: const InputDecoration(labelText: 'Base URL')),
              const SizedBox(height: 8),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(controller: modelController, decoration: const InputDecoration(labelText: 'Model')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final index = appState.aiProviders.indexWhere((p) => p.id == provider.id);
              if (index != -1) {
                appState.aiProviders[index] = AIProvider(
                  id: provider.id,
                  name: nameController.text,
                  type: type,
                  baseUrl: urlController.text,
                  apiKey: keyController.text,
                  model: modelController.text,
                  summaryPrompt: provider.summaryPrompt,
                );
                appState.saveSettings();
              }
              Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportSettingsToFile(BuildContext context, AppState appState) async {
    // Step 1: Ask whether to include API keys
    final includeKey = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Settings'),
        content: const Text(
          'Include API keys in export?\n\nWarning: This stores sensitive credentials in the file.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Exclude Keys')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Include Keys')),
        ],
      ),
    );
    if (includeKey == null) return;

    // Step 2: Pick folder
    String? folderPath;
    try {
      folderPath = await FilePicker.platform.getDirectoryPath(
        dialogTitle: 'Select folder to save settings file',
      );
    } catch (e) {
      // Fallback: use home directory
      folderPath = Platform.environment['HOME'] ?? '/home/${Platform.environment["USER"] ?? "user"}';
    }

    if (folderPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No folder selected')),
      );
      return;
    }

    // Step 3: Ask for filename
    final fileNameController = TextEditingController(
      text: 'nowrss_settings_${DateTime.now().toIso8601String().split("T").first}.json',
    );

    final fileName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Save As'),
        content: TextField(
          controller: fileNameController,
          decoration: const InputDecoration(
            labelText: 'Filename',
            suffixText: '.json',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, fileNameController.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (fileName == null || fileName.isEmpty) return;

    // Ensure .json extension
    final safeFileName = fileName.endsWith('.json') ? fileName : '$fileName.json';
    final fullPath = '$folderPath/$safeFileName';

    try {
      final file = File(fullPath);
      final settings = appState.exportSettings(includeApiKey: includeKey);
      final json = const JsonEncoder.withIndent('  ').convert(settings);
      await file.writeAsString(json);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings saved to: $fullPath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }

  Future<void> _importSettingsFromFile(BuildContext context, AppState appState) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        dialogTitle: 'Select a NowRSS settings JSON file to import',
        allowMultiple: false,
      );
      if (result == null || result.files.single.path == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No file selected')),
        );
        return;
      }

      final filePath = result.files.single.path!;
      final fileName = result.files.single.name;

      // Show confirmation dialog with file details
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import Settings?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('File: $fileName'),
              const SizedBox(height: 8),
              Text(
                'Path: $filePath',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              const Text(
                'This will overwrite your current settings, including Feedbin credentials and AI providers.',
                style: TextStyle(color: Colors.orange),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );

      if (confirmed != true) return;

      final file = File(filePath);
      await appState.importSettingsFromFile(file);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Settings imported from: $filePath')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Import failed: $e')),
      );
    }
  }

  void _showLogViewer(BuildContext context, AppState appState) {
    final path = appState.logger.logFilePath;
    if (path == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No log file available')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log File'),
        content: SizedBox(
          width: 800,
          height: 500,
          child: FutureBuilder<String>(
            future: File(path).readAsString(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return SingleChildScrollView(
                  child: SelectableText(
                    snapshot.data!,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
