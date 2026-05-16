import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import 'feed_tree.dart';
import 'article_list.dart';
import 'reading_pane.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<AppState>(
        builder: (context, appState, child) {
          // Show error snackbar
          if (appState.error != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(appState.error!),
                  backgroundColor: Colors.red,
                  action: SnackBarAction(
                    label: 'DISMISS',
                    onPressed: () => appState.clearError(),
                  ),
                ),
              );
            });
          }

          return Column(
            children: [
              // Progress bar
              if (appState.isLoading)
                LinearProgressIndicator(
                  value: appState.progress > 0 ? appState.progress : null,
                  backgroundColor: Colors.transparent,
                ),
              
              // Progress label
              if (appState.isLoading && appState.progressLabel.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    appState.progressLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              
              // Main three-pane layout
              Expanded(
                child: Row(
                  children: [
                    // Left: Feed Tree
                    SizedBox(
                      width: 250,
                      child: FeedTree(
                        onFeedSelected: (feedId) {
                          // TODO: Filter articles by feed
                        },
                        onViewChanged: (view) {
                          appState.setView(view);
                        },
                      ),
                    ),
                    
                    // Divider
                    const VerticalDivider(width: 1),
                    
                    // Center: Article List
                    Expanded(
                      flex: 1,
                      child: ArticleList(
                        onArticleSelected: (article) {
                          appState.selectArticle(article);
                        },
                        onMarkAllRead: () {
                          _confirmMarkAllRead(context, appState);
                        },
                      ),
                    ),
                    
                    // Divider
                    const VerticalDivider(width: 1),
                    
                    // Right: Reading Pane
                    Expanded(
                      flex: 2,
                      child: ReadingPane(
                        article: appState.selectedArticle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _confirmMarkAllRead(BuildContext context, AppState appState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mark all as read?'),
        content: const Text('This will mark all articles in the current view as read.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL'),
          ),
          ElevatedButton(
            onPressed: () {
              appState.markAllAsRead();
              Navigator.pop(context);
            },
            child: const Text('MARK ALL READ'),
          ),
        ],
      ),
    );
  }
}
