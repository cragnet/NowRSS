import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_state.dart';
import '../models/article.dart';
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
          return Column(
            children: [
              // Progress bar
              if (appState.isLoading)
                LinearProgressIndicator(
                  value: appState.progress > 0 ? appState.progress : null,
                  backgroundColor: Colors.transparent,
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
}
