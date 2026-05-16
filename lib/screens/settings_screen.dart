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

  @override
  void initState() {
    super.initState();
    final appState = context.read<AppState>();
    // Pre-fill if credentials exist
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
                // Feedbin Section
                _buildSectionTitle('Feedbin Account'),
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
                                label: const Text('Save & Test'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // AI Providers Section
                _buildSectionTitle('AI Providers'),
                ...appState.aiProviders.map((provider) => _buildProviderCard(provider, appState)),
                
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: () => _showAddProviderDialog(context, appState),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Provider'),
                ),

                const SizedBox(height: 24),

                // Keyword Filters Section
                _buildSectionTitle('Keyword Filters'),
                const Text(
                  'Articles containing these keywords will be automatically marked as read:',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    ...appState.filterKeywords.map((keyword) => Chip(
                      label: Text(keyword),
                      deleteIcon: const Icon(Icons.close, size: 16),
                      onDeleted: () => appState.removeFilterKeyword(keyword),
                    )),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
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

                const SizedBox(height: 24),

                // Data Management Section
                _buildSectionTitle('Data Management'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.download),
                        title: const Text('Export Settings'),
                        subtitle: const Text('Save configuration to JSON file'),
                        onTap: () => _exportSettings(context, appState),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.upload),
                        title: const Text('Import Settings'),
                        subtitle: const Text('Restore from JSON file'),
                        onTap: () => _importSettings(context, appState),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // App Info
                _buildSectionTitle('About'),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info),
                    title: const Text('NowRSS'),
                    subtitle: const Text('Version 0.1.0'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(String title) {
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

  Widget _buildProviderCard(AIProvider provider, AppState appState) {
    final isDefault = appState.defaultProvider?.id == provider.id;
    
    return Card(
      child: ListTile(
        leading: Icon(
          Icons.psychology,
          color: isDefault ? Colors.amber : null,
        ),
        title: Text(provider.name),
        subtitle: Text('${provider.type} · ${provider.model}'),
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
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
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
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Base URL'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'API Key (optional)'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
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
              TextField(
                controller: urlController,
                decoration: const InputDecoration(labelText: 'Base URL'),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: keyController,
                decoration: const InputDecoration(labelText: 'API Key'),
                obscureText: true,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: modelController,
                decoration: const InputDecoration(labelText: 'Model'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
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

  Future<void> _exportSettings(BuildContext context, AppState appState) async {
    final includeKey = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Export Settings'),
        content: const Text(
          'Do you want to include API keys in the export?\n\n'
          'Warning: This will store sensitive credentials in the exported file.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No, exclude keys'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, include keys'),
          ),
        ],
      ),
    );

    if (includeKey == null) return;

    final settings = appState.exportSettings(includeApiKey: includeKey);
    final json = const JsonEncoder.withIndent('  ').convert(settings);
    
    // For now, show in a dialog — file picker can be added later
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exported Settings'),
        content: SingleChildScrollView(
          child: SelectableText(json),
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

  Future<void> _importSettings(BuildContext context, AppState appState) async {
    final controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Settings'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Paste JSON here',
            hintText: '{"version": "1.0", ...}',
          ),
          maxLines: 10,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              try {
                final settings = jsonDecode(controller.text);
                appState.importSettings(settings);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings imported successfully')),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Invalid JSON: $e')),
                );
              }
            },
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }
}
