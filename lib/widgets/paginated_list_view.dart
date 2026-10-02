import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// A reusable paginated list.
///
/// - First page loads once via [firstPageQuery]
/// - Next pages load on "Load More" tap via [nextPageLoader]
/// - Total docs = sum of all loaded pages
///
/// Usage:
/// ```dart
/// PaginatedListView<PostModel>(
///   firstPageQuery: () => FirebaseFirestore.instance
///       .collection('posts').orderBy('createdAt', descending: true).limit(20),
///   nextPageLoader: (lastDoc) => FirebaseFirestore.instance
///       .collection('posts').orderBy('createdAt', descending: true)
///       .startAfterDocument(lastDoc).limit(20),
///   itemBuilder: (context, doc) => PostCard(post: PostModel.fromDoc(doc)),
///   emptyBuilder: (context) => Text('No posts'),
/// )
/// ```
class PaginatedListView<T> extends StatefulWidget {
  /// Loads the first 20 documents.
  final Query Function() firstPageQuery;

  /// Given the last loaded doc, loads the next 20.
  final Query Function(DocumentSnapshot lastDoc) nextPageLoader;

  /// Builds a single row for each doc.
  final Widget Function(BuildContext, DocumentSnapshot) itemBuilder;

  /// Optional: what to show when the list is empty.
  final Widget Function(BuildContext)? emptyBuilder;

  /// Optional: what to show while loading the first page.
  final Widget Function(BuildContext)? loadingBuilder;

  /// Optional: number of items per page (for hasMore check). Default 20.
  final int pageSize;

  /// Optional: separator builder between rows.
  final Widget Function(BuildContext, int)? separatorBuilder;

  /// Optional: padding for the list.
  final EdgeInsetsGeometry padding;

  /// Optional: callback for when list finishes loading (useful for parent state).
  final void Function(List<DocumentSnapshot>)? onLoaded;

  const PaginatedListView({
    super.key,
    required this.firstPageQuery,
    required this.nextPageLoader,
    required this.itemBuilder,
    this.emptyBuilder,
    this.loadingBuilder,
    this.separatorBuilder,
    this.pageSize = 20,
    this.padding = const EdgeInsets.only(bottom: 20),
    this.onLoaded,
  });

  @override
  State<PaginatedListView<T>> createState() => PaginatedListViewState<T>();
}

class PaginatedListViewState<T> extends State<PaginatedListView<T>> {
  final List<DocumentSnapshot> _docs = [];
  DocumentSnapshot? _lastDoc;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadFirstPage();
  }

  Future<void> _loadFirstPage() async {
    setState(() {
      _initialLoading = true;
      _error = null;
    });
    try {
      final snap = await widget.firstPageQuery().get();
      _docs
        ..clear()
        ..addAll(snap.docs);
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : null;
      _hasMore = snap.docs.length == widget.pageSize;
      widget.onLoaded?.call(_docs);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _initialLoading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _lastDoc == null) return;
    setState(() => _loadingMore = true);
    try {
      final snap = await widget.nextPageLoader(_lastDoc!).get();
      _docs.addAll(snap.docs);
      _lastDoc = snap.docs.isNotEmpty ? snap.docs.last : _lastDoc;
      _hasMore = snap.docs.length == widget.pageSize;
      widget.onLoaded?.call(_docs);
    } catch (e) {
      _error = '$e';
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> refresh() async {
    await _loadFirstPage();
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return widget.loadingBuilder?.call(context) ??
          const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 50, color: Colors.red),
              const SizedBox(height: 12),
              Text('Error: $_error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loadFirstPage,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_docs.isEmpty) {
      return widget.emptyBuilder?.call(context) ??
          const Center(child: Text('No items'));
    }

    final itemCount = _docs.length + 1; // +1 for the Load More button

    return ListView.separated(
      padding: widget.padding,
      itemCount: itemCount,
      separatorBuilder: (context, index) {
        if (widget.separatorBuilder != null) {
          return widget.separatorBuilder!(context, index);
        }
        return const SizedBox.shrink();
      },
      itemBuilder: (context, index) {
        if (index == _docs.length) {
          // Load More button (or end message)
          return _buildFooter();
        }
        return widget.itemBuilder(context, _docs[index]);
      },
    );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            height: 24,
            width: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_hasMore) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(
            '— End of list —',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.expand_more, size: 18),
          label: const Text('Load More'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20)),
          ),
        ),
      ),
    );
  }
}

