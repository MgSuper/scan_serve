sealed class AppState<T> {
  const AppState();
}

class Initial<T> extends AppState<T> {
  const Initial();
}

class Loading<T> extends AppState<T> {
  const Loading();
}

class Success<T> extends AppState<T> {
  final T data;

  const Success(this.data);
}

class Empty<T> extends AppState<T> {
  const Empty();
}

class Error<T> extends AppState<T> {
  final String message;

  const Error(this.message);
}

class Refreshing<T> extends AppState<T> {
  final T oldData;

  const Refreshing(this.oldData);
}

class Paginating<T> extends AppState<T> {
  final T oldData;

  const Paginating(this.oldData);
}

/**
 * Example Cubit
 *
class UsersCubit extends Cubit<AppState<List<User>>> {
  UsersCubit() : super(const Initial());

  Future<void> fetchUsers() async {
    emit(const Loading());

    try {
      final users = await repo.getUsers();

      if (users.isEmpty) {
        emit(const Empty());
      } else {
        emit(Success(users));
      }
    } catch (e) {
      emit(Error(e.toString()));
    }
  }
}
*
*/

/**
 * Example Cubit
 *
BlocBuilder<UsersCubit, AppState<List<User>>>(
  builder: (context, state) {
    switch (state) {
      case Loading():
        return const UsersSkeleton();

      case Empty():
        return const Text('No users');

      case Error():
        return Text(state.message);

      case Success():
        return UsersList(users: state.data);

      default:
        return const SizedBox();
    }
  },
)
*
*/

// class AppState<T> extends Equatable {
//   final AppStatus status;
//   final T? data;
//   final String? message;

//   const AppState({this.status = AppStatus.initial, this.data, this.message});

//   AppState<T> copyWith({AppStatus? status, T? data, String? message}) {
//     return AppState(
//       status: status ?? this.status,
//       data: data ?? this.data,
//       message: message ?? this.message,
//     );
//   }

//   bool get isLoading => status == AppStatus.loading;
//   bool get isSuccess => status == AppStatus.success;
//   bool get isEmpty => status == AppStatus.empty;
//   bool get isError => status == AppStatus.error;
//   bool get isRefreshing => status == AppStatus.refreshing;
//   bool get isPaginating => status == AppStatus.paginating;

//   @override
//   List<Object?> get props => [status, data, message];
// }

/**
 * example usage
 *
 class UsersCubit extends Cubit<AppState<List<User>>> {
  UsersCubit() : super(const AppState());

  Future<void> fetchUsers() async {
    emit(state.copyWith(status: AppStatus.loading));

    try {
      final users = await repo.getUsers();

      if (users.isEmpty) {
        emit(state.copyWith(status: AppStatus.empty));
      } else {
        emit(state.copyWith(
          status: AppStatus.success,
          data: users,
        ));
      }
    } catch (e) {
      emit(state.copyWith(
        status: AppStatus.error,
        message: e.toString(),
      ));
    }
  }
}
*
*/

/**
 * example usage
 *
AppSkeleton(
  loading: state.isLoading,
  child: UsersList(...)
)
*
*/
